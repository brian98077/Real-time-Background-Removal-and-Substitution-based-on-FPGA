import cv2
import numpy as np
import pywt

def dwt_bg_subtract_my_kernel(current_frame, bg_frame, new_back):
    fg_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
    bg_gray = cv2.cvtColor(bg_frame, cv2.COLOR_BGR2GRAY)

    fg_B, fg_G, fg_R = cv2.split(current_frame)
    
    mean_B = np.mean(fg_B.astype(np.uint8))
    mean_G = np.mean(fg_G.astype(np.uint8))
    mean_R = np.mean(fg_R.astype(np.uint8))
    std_B = np.var(fg_B.astype(np.uint8))
    std_G = np.var(fg_G.astype(np.uint8))
    std_R = np.var(fg_R.astype(np.uint8))

    alpha = ((fg_B.astype(np.uint8) * mean_B) / std_B + (fg_G.astype(np.uint8) * mean_G) / std_G + (fg_R.astype(np.uint8) * mean_R) / std_R) /\
    (mean_B * mean_B / std_B + mean_G * mean_G / std_G + mean_R * mean_R / std_R)
    
    alpha_hat = (alpha - 0.5)/alpha
    shadow = (alpha_hat < 0).astype(np.uint8)
    shadow = cv2.resize(shadow, (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST)

    # (2 x 2 mean filter) x 4 + 2D DWT
    kernel = np.array([[0.0625, 0.125, 0.0625], [0.125, 0.25, 0.125], [0.0625, 0.125, 0.0625]])
    fg_kernel = cv2.filter2D(fg_gray.astype(np.uint8), -1, kernel)


    difference_1 = np.abs(fg_kernel - bg_gray)
    #wmse = np.sum((LL_fg.astype(np.uint8) - LL_bg.astype(np.uint8))**2) / (LL_fg.size)
    wmse_1 = np.sum((fg_kernel.astype(np.uint8) - bg_gray.astype(np.uint8))**2) / (fg_kernel.size)
    thresh_1 = wmse_1 / 2 + 32

    mask_1 = (difference_1 >= thresh_1).astype(np.uint8)
    mask_1 = cv2.resize(mask_1, (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST)

    result = current_frame.copy()
    result[shadow == 1] = 0
    result[mask_1 == 0] = 0

    #result[mask_1 == 0] = new_back[mask_1 == 0]
    return result


cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 480)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 640)
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
        output_1 = dwt_bg_subtract_my_kernel(frame, bg_frame, new_back)
        cv2.imshow("result", output_1)

    if key == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
