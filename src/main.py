print("first Line")
from flask import Flask, render_template, Response
print("Second Line")
import cv2  
print("Third Line")
import time
print("Fourth Line")

app = Flask(__name__)

cameraPort = 4

camera = cv2.VideoCapture(cameraPort)  # use 0 for web camera
#  for cctv camera use rtsp://username:password@ip_address:554/user=username_password='password'_channel=channel_number_stream=0.sdp' instead of camera
# for local webcam use cv2.VideoCapture(0)
print("Setup Camera On Port " + str(cameraPort))

def gen_frames():  # generate frame by frame from camera
    while True:
        # Capture frame-by-frame
        success, frame = camera.read()  # read the camera frame
        if not success:
            print("Can cot Read Camera")
            break
        else:
            ret, buffer = cv2.imencode('.jpg', frame)
            frame = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')  # concat frame one by one and show result


@app.route('/video_feed')
def video_feed():
    print("Starting Video Feed")
    #Video streaming route. Put this in the src attribute of an img tag
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/')
def index():
    print("Index()")
    """Video streaming home page."""
    return render_template('index.html')


if __name__ == '__main__':
    app.run(host="0.0.0.0", debug=True)
