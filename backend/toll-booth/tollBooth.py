# THIS IS A TOLL BOOTH

import os
import cv2
import time
from flask import Flask, jsonify
from paddleocr import PaddleOCR
import pymongo
from json import loads
import math

TOLL_ID = "navtoll123"

app = Flask(__name__)

client = pymongo.MongoClient("mongodb://app:roadtrip123@127.0.0.1:27017/admin")  
db = client["app"]  

accounts_col = db["accounts"]
balance_col = db["balances"]
license_plates_col = db["licensePlates"]
tolls_col = db["tolls"]

ocr = PaddleOCR(use_angle_cls=True, lang="en")

def is_us_state(state_name):
    us_states = {
        "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado", "Connecticut", "Delaware", 
        "Florida", "Georgia", "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", 
        "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota", "Mississippi", 
        "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey", "New Mexico", 
        "New York", "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon", "Pennsylvania", 
        "Rhode Island", "South Carolina", "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", 
        "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
    }

    return state_name.title() in us_states  

TEMP_IMAGE_PATH = "temp_plate.jpg"
@app.route('/capture', methods=['GET'])
def capture_and_recognize():
      cap = cv2.VideoCapture(0)
      ret, frame = cap.read()
      cap.release()

    
      if not ret:
            return jsonify({"error": "Failed to capture image"}), 500

      cv2.imwrite(TEMP_IMAGE_PATH, frame)

      ocr_results = ocr.ocr(TEMP_IMAGE_PATH, cls=True)

     
      if os.path.exists(TEMP_IMAGE_PATH):
            os.remove(TEMP_IMAGE_PATH)

      extracted_text = []
      if ocr_results and ocr_results[0]:  
            for res in ocr_results[0]:
                  extracted_text.append(res[1][0])  

      if len(extracted_text) < 2:
            return jsonify({"error": "Failed to detect a valid license plate"}), 400

    
      formatted_string = f"{extracted_text[1]}::{extracted_text[0].replace(' ', '-')}"
      if is_us_state(extracted_text[0]):
            formatted_string = f"{extracted_text[0]}::{extracted_text[1].replace(' ', '-')}"

      print(formatted_string)

      user_entry = license_plates_col.find_one(
      {"license_plates": {"$in": [formatted_string]}},  
      {"_id": 0, "email": 1} 
      )

      print("User Entry:", user_entry)  

      if not user_entry:
            return jsonify({"error": "License plate not found in database"}), 404

      email = user_entry["email"]
      balance_entry = balance_col.find_one({"email": email}, {"_id": 0, "amount": 1})

      print("Balance Entry:", balance_entry) 

      if not balance_entry:
            return jsonify({"error": "Balance not found for this user"}), 404

      
      user_balance = balance_entry.get("amount")

      if user_balance is None:
            return jsonify({"error": "Amount field not found"}), 404

      toll_entry = tolls_col.find_one(
    {"tid": TOLL_ID}, 
    {"_id": 0, "toll_amount": 1, "lat": 1, "lon": 1}  
)
      
      toll_amount = toll_entry.get("toll_amount")
      lat_t = toll_entry.get("lat")
      lon_t = toll_entry.get("lon")

      new_balance = user_balance - toll_amount

      if verifyTx(email, new_balance, TOLL_ID, lat_t, lon_t):
            result = balance_col.update_one(
            {"email": email},
            {"$set": {"amount": new_balance}}
            )
            return "toll paid",200
      else:
            return "SCAM",403

import requests

def haversine(lat1, lon1, lat2, lon2):
    R = 6371  
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])  

    dlat = lat2 - lat1
    dlon = lon2 - lon1

    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    return R * c  

def verifyTx(email, tid, balance, lat_t, lon_t):
      url = "https://able-only-chamois.ngrok-free.app/getUserCoords"  
      headers = {
        "Content-Type": "application/json"
      }
      
      response = requests.get(url)
      data = response.json()

      lat_u = data["latlon"]["latitude"]
      lon_u = data["latlon"]["longitude"]
      distance = haversine(lat_u, lon_u, lat_t, lon_t)
    
      print(f"Distance between user and transaction location: {distance:.2f} km")

      if distance <= 2:  
            return True
      else:
            return False
      
if __name__ == "__main__":
      app.run(port=5002,debug=True)
