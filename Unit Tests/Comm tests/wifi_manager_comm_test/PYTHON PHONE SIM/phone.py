from google.cloud import firestore
from datetime import datetime
import pytz

# Initialize Firestore client
db = firestore.Client.from_service_account_json("serviceAccountKey.json")

def simulate_pairing(device_id, user_uid="V6dghQgXSaafFtSq8zbNREgR1wY2", user_id="user123"):
    doc_ref = db.collection("pairing_requests").document(device_id)

    try:
        doc = doc_ref.get()
        if doc.exists:
            data = doc.to_dict()
            status = data.get("status", "")
            print(f"Current status: {status}")  # Debug output
            if status == "pending":
                print(f"Found pending pairing request for device: {device_id}")
                update_data = {
                    "status": "approved",
                    "uid": user_uid,
                    "user_id": user_id,  # New field
                    "deviceId": device_id,
                    "createdAt": data.get("createdAt", "")
                }
                doc_ref.set(update_data, merge=True)
                print(f"Pairing approved for device {device_id} with UID {user_uid} and user_id {user_id}")
            else:
                print(f"Pairing request not pending (status: {status})")
        else:
            print(f"No pairing request found for device {device_id}")
    except Exception as e:
        print(f"Error: {e}")

def main():
    device_id = "F4:65:0B:46:F7:28".replace(":", "-").upper()
    user_uid = "V6dghQgXSaafFtSq8zbNREgR1wY2"
    user_id = "user123"  # Example user_id
    
    idt = pytz.timezone('Asia/Jerusalem')
    current_time = datetime.now(idt).strftime('%Y-%m-%d %H:%M:%S %Z')
    print(f"Current time (IDT): {current_time}")
    
    simulate_pairing(device_id, user_uid, user_id)

if __name__ == "__main__":
    main()