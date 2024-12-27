import cv2
import numpy as np
import pywt

def dwt_bg_subtract(current_frame, new_back):
    fg_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
    fg_median = cv2.medianBlur(fg_gray, 3)

    # LL_fg, (LH_fg, HL_fg, HH_fg) = pywt.dwt2(fg_median, 'haar')
    dwt_kernel = np.array([[0.25, 0.25], [0.25, 0.25]])
    LL_fg = cv2.filter2D(fg_median.astype(np.uint8), -1, dwt_kernel)

    # Show the grayscale LL components
    cv2.imshow("LL_fg", LL_fg.astype(np.uint8))

    avg  = (np.sum(LL_fg.astype(np.uint8)) / (LL_fg.size)).astype(np.uint8)
    #print("avg  ",avg)
    wmse = (np.sum((LL_fg.astype(np.uint8) - avg.astype(np.uint8))**2) / (LL_fg.size)).astype(np.uint8)
    #print("wmse ", wmse)
    difference = np.abs(LL_fg - avg)
    thresh = (wmse).astype(np.uint8) * 1.5

    mask = (difference < thresh).astype(np.uint8)
    mask = cv2.resize(mask, (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST)

    result = current_frame.copy()
    #result[mask == 0] = 0
    result[mask == 0] = new_back[mask == 0]
    return result

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 600)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 800)
cap.set(cv2.CAP_PROP_FPS, 60)
bg_frame = None
new_back = cv2.imread("image/virtual_back.jpg", flags = 1)
new_back = cv2.resize(new_back, (640, 480), interpolation=cv2.INTER_AREA)
cv2.imshow("new_background", new_back)

while True:
    ret, frame = cap.read()
    if not ret:
        break

    cv2.imshow("Live", frame)

    key = cv2.waitKey(1) & 0xFF
    if key == ord('b'):
        bg_frame = frame.copy()
    if bg_frame is not None:
        output = dwt_bg_subtract(frame, new_back)
        cv2.imshow("Result", output)

    if key == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
