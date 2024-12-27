import cv2
import numpy as np
import pywt
import time

def dwt_bg_subtract(current_frame, bg_frame, new_back):

    fg_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
    bg_gray = cv2.cvtColor(bg_frame, cv2.COLOR_BGR2GRAY)

    # (2 x 2 mean filter) x 4 + 2D DWT
    kernel = np.array([[0.0625, 0.125, 0.0625], [0.125, 0.25, 0.125], [0.0625, 0.125, 0.0625]])
    fg_mean = cv2.filter2D(fg_gray.astype(np.uint8), -1, kernel)


    difference_1 = np.abs(fg_mean - bg_gray)
    #wmse = np.sum((LL_fg.astype(np.uint8) - LL_bg.astype(np.uint8))**2) / (LL_fg.size)
    wmse_1 = np.sum((fg_mean.astype(np.uint8) - bg_gray.astype(np.uint8))**2) / (fg_mean.size)
    thresh_1 = wmse_1 / 2 + 32

    mask_1 = (difference_1 >= thresh_1).astype(np.uint8)
    mask_1 = cv2.resize(mask_1, (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST)

    # Sobel edge detection
    sobelx_fg = cv2.Sobel(fg_gray, cv2.CV_32F, 1, 0, ksize=3)
    sobely_fg = cv2.Sobel(fg_gray, cv2.CV_32F, 0, 1, ksize=3)
    sobel_fg = cv2.magnitude(sobelx_fg, sobely_fg)
    sobel_fg = np.uint8(sobel_fg)

    sobelx_bg = cv2.Sobel(bg_gray, cv2.CV_32F, 1, 0, ksize=3)
    sobely_bg = cv2.Sobel(bg_gray, cv2.CV_32F, 0, 1, ksize=3)
    sobel_bg = cv2.magnitude(sobelx_bg, sobely_bg)
    sobel_bg = np.uint8(sobel_bg)

    result = current_frame.copy()
    sobel  = current_frame.copy()
    #result[mask_1 == 0] = new_back[mask_1 == 0]
    result[mask_1 == 0] = 0

    # difference_sobel = np.abs(sobel_fg - sobel_bg)
    #wmse = np.sum((LL_fg.astype(np.uint8) - LL_bg.astype(np.uint8))**2) / (LL_fg.size)
    # wmse_sobel = np.sum((sobel_fg.astype(np.uint8) - sobel_bg.astype(np.uint8))**2) / (sobel_fg.size)
    # thresh_sobel = wmse_sobel / 2

    mask_sobel_bg = (sobel_bg >= 50).astype(np.uint8)
    mask_sobel_fg = (sobel_fg <  50).astype(np.uint8)
    mask_sobel = mask_sobel_bg + mask_sobel_fg
    mask_sobel = cv2.resize(mask_sobel, (sobel_fg.shape[1], sobel_bg.shape[0]), interpolation=cv2.INTER_NEAREST)

    sobel[mask_1 == 0] = 0
    sobel[mask_sobel == 2] = 0

    cv2.imshow("mask", result)
    cv2.imshow("sobel", sobel)

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 480)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 600)
cap.set(cv2.CAP_PROP_FPS, 60)
new_back = cv2.imread("image/virtual_back.jpg", flags = 1)
new_back = cv2.resize(new_back, (640, 480), interpolation=cv2.INTER_AREA)
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
            dwt_bg_subtract(frame, bg_frame, new_back)

    key = cv2.waitKey(1) & 0xFF
    if key == ord('b'):
        bg_frame = frame.copy()
    elif key == ord('q'):
        break
    elif key == ord(' '):
        paused = not paused

cap.release()
cv2.destroyAllWindows()
