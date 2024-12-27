import cv2
import numpy as np
import pywt

LEARNING_RATE = 250

def dwt_bg_subtract(current_frame, bg_gray, new_back):
    fg_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
    #bg_gray = cv2.cvtColor(bg_frame, cv2.COLOR_BGR2GRAY)

    fg_mean = cv2.blur(fg_gray, (4,4))
    bg_mean = cv2.blur(bg_gray, (4,4))
    fg_guass = cv2.GaussianBlur(fg_gray, (3,3), 0)
    bg_guass = cv2.GaussianBlur(bg_gray, (3,3), 0)

    LL_fg, (LH_fg, HL_fg, HH_fg) = pywt.dwt2(fg_gray, 'haar')
    LL_bg, (LH_bg, HL_bg, HH_bg) = pywt.dwt2(bg_gray, 'haar')

    # Show the grayscale LL components
    cv2.imshow("LL_fg", LL_fg.astype(np.uint8))
    cv2.imshow("LL_bg", LL_bg.astype(np.uint8))

    difference_1 = np.abs(fg_mean - bg_gray)
    difference_2 = np.abs(fg_guass - bg_gray)
    #wmse = np.sum((LL_fg.astype(np.uint8) - LL_bg.astype(np.uint8))**2) / (LL_fg.size)
    wmse_1 = np.sum((fg_mean.astype(np.uint8) - bg_gray.astype(np.uint8))**2) / (fg_mean.size)
    wmse_2 = np.sum((fg_guass.astype(np.uint8) - bg_gray.astype(np.uint8))**2) / (fg_mean.size)
    thresh_1 = wmse_1 / 2
    thresh_2 = wmse_2 / 2
    print(thresh_1)

    mask_1 = (difference_1 >= thresh_1).astype(np.uint8)
    mask_2 = (difference_2 >= thresh_2).astype(np.uint8)
    mask_1 = cv2.resize(mask_1, (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST)
    mask_2 = cv2.resize(mask_2, (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST)

    result = current_frame.copy()
    #result[mask == 0] = 0
    result[mask_1 == 0] = new_back[mask_1 == 0]
    return result

def dwt_bg_subtract_guass(current_frame, bg_frame, new_back):
    fg_gray = cv2.cvtColor(current_frame, cv2.COLOR_BGR2GRAY)
    bg_gray = cv2.cvtColor(bg_frame, cv2.COLOR_BGR2GRAY)

    fg_guass = cv2.GaussianBlur(fg_gray, (3,3), 0)
    bg_guass = cv2.GaussianBlur(bg_gray, (3,3), 0)

    LL_fg, (LH_fg, HL_fg, HH_fg) = pywt.dwt2(fg_gray, 'haar')
    LL_bg, (LH_bg, HL_bg, HH_bg) = pywt.dwt2(bg_gray, 'haar')

    # Show the grayscale LL components
    cv2.imshow("LL_fg", LL_fg.astype(np.uint8))
    cv2.imshow("LL_bg", LL_bg.astype(np.uint8))

    difference_2 = np.abs(fg_guass - bg_gray)
    #wmse = np.sum((LL_fg.astype(np.uint8) - LL_bg.astype(np.uint8))**2) / (LL_fg.size)
    wmse_2 = np.sum((fg_guass.astype(np.uint8) - bg_gray.astype(np.uint8))**2) / (fg_guass.size)
    thresh_2 = wmse_2 / 2

    mask_2 = (difference_2 >= thresh_2).astype(np.uint8)
    mask_2 = cv2.resize(mask_2, (fg_gray.shape[1], fg_gray.shape[0]), interpolation=cv2.INTER_NEAREST)

    result = current_frame.copy()
    #result[mask == 0] = 0
    result[mask_2 == 0] = new_back[mask_2 == 0]
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
        bg_gray = cv2.cvtColor(bg_frame, cv2.COLOR_BGR2GRAY)
    if bg_frame is not None:
        output_1 = dwt_bg_subtract(frame, bg_gray, new_back)
        cv2.imshow("mean_result", output_1)
        output_2 = dwt_bg_subtract_guass(frame, bg_frame, new_back)
        cv2.imshow("guass_result", output_2)

        # background adaption
        fg_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        bg_gray = (bg_gray * LEARNING_RATE)/(LEARNING_RATE + 1) + fg_gray/(LEARNING_RATE+1)

    if key == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
