from pymongo import MongoClient
from datetime import datetime
import os
import threading
import time
from json import dumps
import requests
from flask import jsonify, Flask, request
from paddleocr import PaddleOCR
app = Flask(__name__)

client = MongoClient("mongodb://app:roadtrip123@localhost:27017/admin") 
db = client["app"]  

accounts_col = db["accounts"]
balance_col = db["balances"]
license_plates_col = db["licensePlates"]

ocr = PaddleOCR(use_angle_cls=True)

@app.route("/get_balance",methods=["GET"])
def get_balance():
    email = request.args.get("email")
    balance_entry = balance_col.find_one({"email": email}, {"_id": 0, "amount": 1}) 
    return str(balance_entry.get("amount",0)), 200

@app.route("/get_user_info", methods=["GET"])
def get_user_info():
    email = request.args.get("email")  

    user_entry = accounts_col.find_one(
        {"email": email},
        {"_id": 0, "name": 1, "email": 1, "phone": 1, "address": 1})

    user_info_list = [
        user_entry.get("name", ""),
        user_entry.get("email", ""),
        user_entry.get("phone", ""),
        user_entry.get("address","")]

    return user_info_list, 200

@app.route("/my_cars",methods=['GET'])
def my_cars():
    email = request.args.get("email")
    user_entry = license_plates_col.find_one(
        {"email": email},
        {"_id": 0, "license_plates": 1}  
    )

    if not user_entry:
        return jsonify({"error": "No license plates found for this email"}), 404

    license_plates = user_entry.get("license_plates", [])
    license_plate_objects = []
    for plate in license_plates:
        try:
            state, plate_number = plate.split("::")
            plate_number = plate_number.replace("-", "")  

            image_url = f"https://example.com/images/{plate_number}.jpg"

            license_plate_objects.append({
                "state": state.strip(),
                "plate_number": plate_number.strip(),
                "image_url": image_url
            })
        except ValueError:
            continue  

    return jsonify(license_plate_objects), 200

@app.route("/add_user", methods=["POST"])
def add_user():
    data = request.json
    email = data.get("email")
    name = data.get("name")
    street1 = data.get("street1")
    street2 = data.get("street2")
    state = data.get("state")
    city = data.get("city")
    postalcode = data.get("postalcode")
    phone = data.get("phone")
    
    email = data["email"].strip().lower()
    

    if accounts_col.find_one({"email": email}):
        return jsonify({"error": "Email already registered"}), 403

    new_user = {
        "email": email,
        "name": data["name"].strip(),
        "address": data.get("address", ""),
        "phone": data.get("phone", "").strip()
    }

    new_balance = {
            "email":email,
            "amount":0
            }

    inserted2 = balance_col.insert_one(new_balance)

    inserted_doc = accounts_col.insert_one(new_user)
    new_user["_id"] = str(inserted_doc.inserted_id)
    print(new_user)
    return jsonify({"message": "User added successfully", "user": new_user}), 201

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

@app.route("/add_license_plate",methods=['POST'])
def add_license_plate():
    if "image" not in request.files:
        return jsonify({"error": "No image file provided"}), 400
    email = request.form["email"]
    image_file = request.files["image"]
    image_path = os.path.join("uploads", image_file.filename)
    image_file.save(image_path)
    ocr_results = ocr.ocr(image_path, cls=True)
    extracted_text = []
    if ocr_results:
        for res in ocr_results[0]: 
            extracted_text.append(res[1][0])  
    print(extracted_text)
    os.system(f"rm ./uploads/{image_file.filename}/")
    formatted_string = f"{extracted_text[1]}::{extracted_text[0].replace(' ', '-')}"
    if is_us_state(extracted_text[0]):
        formatted_string = f"{extracted_text[0]}::{extracted_text[1].replace(' ', '-')}"
    license_plates_col.update_one(
        {"email": email},
        {"$addToSet": {"license_plates": formatted_string}},  
        upsert=True  
    )
    return "done",200

@app.route("/update_balance",methods=['GET'])
def update_balance():
    email = request.args.get("email")
    funds = float(request.args.get("funds"))
    result = balance_col.find_one_and_update(
            {"email": email},  
            {"$inc": {"amount": funds}}, 
            return_document=True  
        )
    return "done",200
def wait_for_latlon2():
    global latest_latlon
    latlon_event.clear() 

    while not latest_latlon:  
        latlon_event.wait()  

    return latest_latlon 
       
def wait_for_latlon():
    latlon_event.wait()  
    return latest_latlon  
NODE_SERVER_URL = "http://localhost:3001"
latlon_event = threading.Event()
latest_latlon = None  
@app.route('/getUserCoords', methods=['GET'])
def verifytx():
    global latest_latlon
    latest_latlon = None  
    latlon_event.clear()
    try:
        
        requests.get(f"{NODE_SERVER_URL}/trigger")
        print("Waiting for client to respond with lat/lon...")

        
        latlon = wait_for_latlon()

        print(f"Received Latitude/Longitude: {latlon}")
        return jsonify({"status": "success", "latlon": latlon})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/set-latlon', methods=['POST'])
def set_latlon():
    global latest_latlon
    data = request.get_json()
    
    latest_latlon = data
    latlon_event.set()  
    return jsonify({"status": "success","data":data})

if __name__ == "__main__":
    app.run(port=8000,debug=True)
