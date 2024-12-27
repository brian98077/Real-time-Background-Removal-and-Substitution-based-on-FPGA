import cv2
import numpy as np
import pywt
import time

def dwt_bg_subtract(current_frame, bg_frame):
    fg_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
    bg_gray = cv2.cvtColor(bg_frame, cv2.COLOR_BGR2GRAY)
    print(bg_gray[120][170])
    # add a 1*4 kernel to the image (-1, 0, 0, 1)
    kernel = np.array([[0.25, 0.25, 0.25, 0.25]])

    fg_test = cv2.filter2D(fg_gray.astype(np.uint8), -1, kernel)
    bg_test = cv2.filter2D(bg_gray.astype(np.uint8), -1, kernel)
    cv2.imshow("fg_gray", fg_test)
    cv2.imshow("bg_gray", bg_test)

    # LL_fg, (LH_fg, HL_fg, HH_fg) = pywt.dwt2(fg_gray, 'haar')
    # LL_bg, (LH_bg, HL_bg, HH_bg) = pywt.dwt2(bg_gray, 'haar')


    # Show the grayscale LL components
    # cv2.imshow("LL_fg", LL_fg.astype(np.uint8))
    # cv2.imshow("LL_bg", LL_bg.astype(np.uint8))

    difference = np.abs(fg_test - bg_test)
    wmse = 0
    # for i in range(LL_fg.shape[0]):
    #     for j in range(LL_fg.shape[1]):
    #         diff = (LL_fg[i, j].astype(np.uint8) - LL_bg[i, j].astype(np.uint8)) ** 2
    #         wmse += (diff / LL_fg.size).astype(np.float32)
    diff = (fg_test.astype(np.uint8) - bg_test.astype(np.uint8)) ** 2
    wmse = np.sum(diff) / fg_test.size
    wmse = wmse.astype(np.float32)
    thresh = wmse / 2
    print(thresh)
    mask = (difference >= thresh)
    mask = cv2.resize(mask.astype(np.uint8), (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST).astype(bool)

    result = current_frame.copy()
    result[mask == 0] = 0
    return result

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 600)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 800)
cap.set(cv2.CAP_PROP_FPS, 60)
bg_frame = None

paused = False
prev_time = time.time()

while True:
    if not paused:
        ret, frame = cap.read()
        if not ret:
            break

        cv2.imshow("Live", frame)

        if bg_frame is not None:
            output = dwt_bg_subtract(frame, bg_frame)
            cv2.imshow("Result", output)

        # Calculate FPS
        current_time = time.time()
        fps = 1 / (current_time - prev_time)
        prev_time = current_time
        #print(f"FPS: {fps:.2f}")

    key = cv2.waitKey(1) & 0xFF
    if key == ord('b'):
        bg_frame = frame.copy()
    elif key == ord('q'):
        break
    elif key == ord(' '):
        paused = not paused

cap.release()
cv2.destroyAllWindows()
