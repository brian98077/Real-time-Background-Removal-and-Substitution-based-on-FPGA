input_image_path = 'image/input_2.jpg';
background_image_path = 'image/bg_2.jpg';
%pure_subtract(input_image_path, background_image_path, 30);
%pure_subtract_rgb(input_image_path, background_image_path, 20000);
%RTBS(input_image_path, background_image_path, 10)
DWT_thres_MSE(input_image_path, background_image_path);
%Gauss_DWT_thres_m_s(input_image_path, background_image_path);

function masked_image = apply_mask(foreground_image, binary_mask)
    % Ensure the mask is logical
    binary_mask = logical(binary_mask);

    % Initialize the masked image as a copy of the foreground image
    masked_image = foreground_image;

    % Set pixels to zero where mask is false
    masked_image(repmat(~binary_mask, [1, 1, 3])) = 0;
end


function binary_image =pure_subtract(foreground_image_path, background_image_path, threshold)
     % 1. 讀取前景和背景影像
    foreground = imread(foreground_image_path);
    background = imread(background_image_path);

    % 轉換為灰階
    foreground = rgb2gray(foreground);
    background = rgb2gray(background);
    
    difference = abs(foreground - background);

    binary_image = difference >= threshold;
    output = apply_mask(imread(foreground_image_path), binary_image);
    figure;
    sgtitle('Pure subtract gray');
    subplot(2, 2, 1), imshow(imread(foreground_image_path)), title('forground');
    subplot(2, 2, 2), imshow(imread(background_image_path)), title('background');
    subplot(2, 2, 3), imshow(binary_image), title('mask');
    subplot(2, 2, 4), imshow(output), title('result');
end

function binary_image = pure_subtract_rgb(foreground_image_path, background_image_path, threshold)
    % 1. 讀取前景和背景影像
    foreground = imread(foreground_image_path);
    background = imread(background_image_path);

    % 確保影像為double類型，以便計算平方
    foreground = double(foreground);
    background = double(background);

    % 2. 將RGB三個頻道平方後相加
    foreground_squared_sum = foreground(:, :, 1).^2 + foreground(:, :, 2).^2 + foreground(:, :, 3).^2;
    background_squared_sum = background(:, :, 1).^2 + background(:, :, 2).^2 + background(:, :, 3).^2;
    % 3. 計算平方後的絕對差異
    difference = abs(foreground_squared_sum - background_squared_sum);

    % 4. 應用閾值生成二值影像
    binary_image = difference >= threshold;
    output = apply_mask(imread(foreground_image_path), binary_image);

    % 顯示結果
    figure;
    sgtitle('Pure subtract rgb');
    subplot(2, 2, 1), imshow(imread(foreground_image_path)), title('forground');
    subplot(2, 2, 2), imshow(imread(background_image_path)), title('background');
    subplot(2, 2, 3), imshow(binary_image), title('mask');
    subplot(2, 2, 4), imshow(output), title('result');
end



function binary_image = DWT_thres_MSE(foreground_image_path, background_image_path)
    % HUMAN_DETECTION Detects human presence by background subtraction.
    % Input:
    %   - foreground_image_path: Path to the foreground image file.
    %   - background_image_path: Path to the background image file.
    % Output:
    %   - binary_image: Binary image with detected human presence.
    
    % 1. 讀取前景和背景影像
    foreground = imread(foreground_image_path);
    background = imread(background_image_path);
    
    % rgb
    [rows columns numberOfColorBands] = size(foreground);
    fore_redChannel = foreground(:, :, 1);
    fore_greenChannel = foreground(:, :, 2);
    fore_blueChannel = foreground(:, :, 3);
    
    

    [rows columns numberOfColorBands] = size(background);
    back_redChannel = background(:, :, 1);
    back_greenChannel = background(:, :, 2);
    back_blueChannel = background(:, :, 3);

    % 2. 使用中值濾波器去噪
    fore_redMF = medfilt2(fore_redChannel, [3 3]);
    fore_greenMF = medfilt2(fore_greenChannel, [3 3]);
    fore_blueMF = medfilt2(fore_blueChannel, [3 3]);

    back_redMF = medfilt2(back_redChannel, [3 3]);
    back_greenMF = medfilt2(back_greenChannel, [3 3]);
    back_blueMF = medfilt2(back_blueChannel, [3 3]);
    
    % 平方和開根號
    foreground = sqrt(double(fore_redMF.^2) + double(fore_greenMF.^2) + double(fore_blueMF.^2));
    background = sqrt(double(back_redMF.^2) + double(back_greenMF.^2) + double(back_blueMF.^2));
    % 3. 使用二維小波轉換 (Haar DWT)
    [LL_fg, ~, ~, ~] = dwt2(foreground, 'haar');
    [LL_bg, ~, ~, ~] = dwt2(background, 'haar');
    %imshow(uint8(LL_fg));
    % 4. 背景減除
    difference = abs(LL_fg - LL_bg);

    % 5. 計算自適應閾值
    WMSE = sum(sum((foreground - background).^2)) / (size(foreground, 1) * size(foreground, 2));
    threshold = WMSE ;  % 假設的分割因子為8

    % 6. 閾值處理
    binary_image = difference >= threshold;
    binary_image = imresize(binary_image, size(foreground));
    output = apply_mask(imread(foreground_image_path), binary_image);
    figure;
    sgtitle('DWT thres MSE');
    subplot(2, 2, 1), imshow(imread(foreground_image_path)), title('forground');
    subplot(2, 2, 2), imshow(imread(background_image_path)), title('background');
    subplot(2, 2, 3), imshow(binary_image), title('mask');
    subplot(2, 2, 4), imshow(output), title('result');
end


function binary_image = Gauss_DWT_thres_m_s(foreground_image_path, background_image_path)
    foreground = imread(foreground_image_path);
    background = imread(background_image_path);

    foreground = rgb2gray(foreground);
    background = rgb2gray(background);
    
    % Step 1: Gaussian Filtering
    h = fspecial('gaussian', [3, 3], 0.5);
    filteredInput = imfilter(foreground, h, 'replicate');
    filteredBackground = imfilter(background, h, 'replicate');
    
    % Step 2: Discrete Wavelet Transform (DWT)
    [LL_input, ~, ~, ~] = dwt2(filteredInput, 'db1');
    [LL_background, ~, ~, ~] = dwt2(filteredBackground, 'db1');
    % Step 3: Adaptive Threshold Calculation
    diffLL = abs(LL_input - LL_background);
    threshold = mean(diffLL(:)) + std(diffLL(:)); % Adaptive threshold based on mean and std dev
    
    % Step 4: Background Subtraction
    foregroundMask = diffLL > threshold;
    detectedObject = foregroundMask .* LL_input; % Segment the object
    % Step 5: Filter and Output
    %detectedObject = imfilter(detectedObject, h, 'replicate'); % Final filtering for quality
    
    % Upsample detected object back to original size for visualization
    binary_image = imresize(detectedObject, size(foreground));

    output = apply_mask(imread(foreground_image_path), binary_image);
    figure;
    sgtitle('Gauss DWT thres_{mean, std}');
    subplot(2, 2, 1), imshow(imread(foreground_image_path)), title('forground');
    subplot(2, 2, 2), imshow(imread(background_image_path)), title('background');
    subplot(2, 2, 3), imshow(binary_image), title('mask');
    subplot(2, 2, 4), imshow(output), title('result');
end





