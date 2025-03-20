import cv2
import numpy as np
import time
import requests
import json
from datetime import datetime
import sys
MIN_DISTANCE_CM = 50      
KNOWN_WIDTH = 20.0          
FOCAL_LENGTH = 500        
MIN_CONTOUR_AREA = 1000
MERGE_DISTANCE = 50        
MOTION_FRAMES = 10        
SHUTDOWN_DELAY = 5         
API_ENDPOINT = f"http://{sys.argv[1]}:5002/capture"

motion_counter = 0
shutdown_triggered = False
shutdown_start_time = 0
last_positions = []
frame_buffer = []
BUFFER_SIZE = 5 

def calculate_distance(pixel_width):
    return (KNOWN_WIDTH * FOCAL_LENGTH) / pixel_width

def merge_boxes(boxes, merge_threshold):
    if len(boxes) == 0:
        return []
    boxes_xyxy = np.array([[x, y, x+w, y+h] for (x, y, w, h) in boxes])
    indices = cv2.dnn.NMSBoxes(boxes_xyxy.tolist(), [1]*len(boxes), 0.5, merge_threshold)
    return [boxes[i] for i in indices]

def is_moving(current_centers, previous_centers, threshold=20):  
    if not previous_centers:
        return False
    for c_center in current_centers:
        for p_center in previous_centers:
            dx = abs(c_center[0] - p_center[0])
            dy = abs(c_center[1] - p_center[1])
            if dx > threshold or dy > threshold:
                return True
    return False

def trigger_api(detection_data):
    headers = {'Content-Type': 'application/json'}
    try:
        response = requests.post(API_ENDPOINT, data=json.dumps(detection_data), headers=headers, timeout=3)
        print(f"API call successful: {response.status_code}")
        return response.ok
    except Exception as e:
        print(f"API call failed: {str(e)}")
        return False

cap = cv2.VideoCapture(0)
fgbg = cv2.createBackgroundSubtractorMOG2(history=500, varThreshold=32, detectShadows=False)  
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

print("Starting motion detection system...")
print("Press 'q' to quit\n")

while True:
    ret, frame = cap.read()
    if not ret: break

    frame_buffer.append(frame)
    if len(frame_buffer) > BUFFER_SIZE:
        frame_buffer.pop(0)
    avg_frame = np.mean(frame_buffer, axis=0).astype(dtype=np.uint8)

    current_centers = []

    gray = cv2.cvtColor(avg_frame, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (21, 21), 0)
    fgmask = fgbg.apply(gray)
    thresh = cv2.threshold(fgmask, 25, 255, cv2.THRESH_BINARY)[1] 
    thresh = cv2.dilate(thresh, None, iterations=2)
    
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    detected_boxes = [cv2.boundingRect(c) for c in contours if cv2.contourArea(c) >= MIN_CONTOUR_AREA]
    
    for (x, y, w, h) in merge_boxes(detected_boxes, 0.3):
        distance = calculate_distance(w)
        current_centers.append((x + w//2, y + h//2))
        
        color = (0, 255, 0) if not shutdown_triggered else (0, 0, 255)
        cv2.rectangle(frame, (x, y), (x+w, y+h), color, 2)

    if is_moving(current_centers, last_positions):
        motion_counter += 1
        if motion_counter >= MOTION_FRAMES and not shutdown_triggered:
            print(f"Confirmed movement detected! Shutdown in {SHUTDOWN_DELAY} seconds...")
            
            detection_data = {
                "timestamp": datetime.now().isoformat(),
                "distance_cm": min([calculate_distance(w) for (x,y,w,h) in detected_boxes]) if detected_boxes else None,
                "object_count": len(detected_boxes),
                "camera_resolution": f"{frame.shape[1]}x{frame.shape[0]}"
            }
            trigger_api(detection_data)
            
            shutdown_triggered = True
            shutdown_start_time = time.time()
    else:
        motion_counter = max(0, motion_counter - 1)

    last_positions = current_centers

    if shutdown_triggered:
        elapsed = time.time() - shutdown_start_time        
        if elapsed >= SHUTDOWN_DELAY:
            break

    cv2.imshow('Movement Detection System', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
if shutdown_triggered:
    print("System shutdown due to confirmed movement")
else:
    print("Manual shutdown by user")
