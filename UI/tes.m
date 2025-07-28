classdef MaskGeneratorApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        UIAxes                  matlab.ui.control.UIAxes
        LoadImageButton         matlab.ui.control.Button
        ClearMaskButton         matlab.ui.control.Button
        SaveMaskButton          matlab.ui.control.Button
        TestButton              matlab.ui.control.Button
        AlternativeButton       matlab.ui.control.Button
        BrushSizeSlider         matlab.ui.control.Slider
        BrushSizeLabel          matlab.ui.control.Label
        StatusLabel             matlab.ui.control.Label
    end
    
    % Private properties
    properties (Access = private)
        CurrentImage            % 当前显示的图像
        MaskImage              % 当前的 mask 图像
        IsDrawing              % 是否正在绘制
        BrushSize              % 画笔大小
        ImageHandle            % 图像句柄
        MaskHandle             % mask 覆盖层句柄
        MouseTimer             % 鼠标检测定时器（备选方案）
        LastMouseState         % 上次鼠标状态
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % 初始化参数
            app.IsDrawing = false;
            app.BrushSize = 10;
            app.BrushSizeSlider.Value = 10;
            
            % 设置坐标轴属性
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            app.UIAxes.Box = 'on';
            title(app.UIAxes, '点击并拖拽生成 Mask');
            
            % 自动加载测试图像
            app.loadDefaultImage();
            
            % 额外提示
            fprintf('\n=== 使用说明 ===\n');
            fprintf('1. 点击"测试回调"按钮测试鼠标事件\n');
            fprintf('2. 在图像上点击拖拽进行绘制\n');
            fprintf('3. 如果不工作，请尝试以下方法：\n');
            fprintf('   - 确保 MATLAB 版本 >= R2018a\n');
            fprintf('   - 检查命令窗口的调试信息\n');
            fprintf('   - 尝试重新加载图像\n');
        end

        % Button pushed function: LoadImageButton
        function LoadImageButtonPushed(app, event)
            % 打开文件对话框选择图像
            [filename, pathname] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tiff', '图像文件'});
            if filename ~= 0
                app.CurrentImage = imread(fullfile(pathname, filename));
                app.displayImage();
                app.initializeMask();
            end
        end

        % Button pushed function: ClearMaskButton
        function ClearMaskButtonPushed(app, event)
            if ~isempty(app.CurrentImage)
                app.initializeMask();
                app.updateMaskDisplay();
            end
        end

        % Button pushed function: SaveMaskButton
        function SaveMaskButtonPushed(app, event)
            if ~isempty(app.MaskImage)
                [filename, pathname] = uiputfile({'*.png', 'PNG 文件'}, 'mask.png');
                if filename ~= 0
                    imwrite(app.MaskImage, fullfile(pathname, filename));
                    msgbox('Mask 已保存!', '成功');
                end
            end
        end

        % Button pushed function: TestButton
        function TestButtonPushed(app, event)
            fprintf('\n=== 测试按钮被点击 ===\n');
            
            % 检查图像状态
            if isempty(app.CurrentImage)
                fprintf('错误：没有加载图像\n');
                app.StatusLabel.Text = '状态：没有图像';
                return;
            end
            
            % 检查图像句柄
            if isempty(app.ImageHandle) || ~isvalid(app.ImageHandle)
                fprintf('错误：图像句柄无效\n');
                app.StatusLabel.Text = '状态：图像句柄无效';
                return;
            end
            
            % 测试方法1：UIAxes 回调
            fprintf('=== 测试方法1：UIAxes回调 ===\n');
            app.UIAxes.ButtonDownFcn = @(~,~) fprintf('>>> UIAxes测试回调成功! <<<\n');
            fprintf('UIAxes测试回调已设置，请点击图像\n');
            
            % 等待3秒后测试方法2
            t1 = timer('TimerFcn', @(~,~) testMethod2(), 'StartDelay', 3);
            start(t1);
            
            function testMethod2()
                fprintf('\n=== 测试方法2：图像对象回调 ===\n');
                set(app.ImageHandle, 'ButtonDownFcn', @(~,~) fprintf('>>> 图像对象测试回调成功! <<<\n'));
                fprintf('图像对象测试回调已设置，请点击图像\n');
                
                % 等待3秒后恢复正常回调
                t2 = timer('TimerFcn', @(~,~) restoreCallbacks(), 'StartDelay', 3);
                start(t2);
            end
            
            function restoreCallbacks()
                fprintf('\n=== 恢复正常回调函数 ===\n');
                app.UIAxes.ButtonDownFcn = @(src, event) app.axesButtonDown(src, event);
                set(app.ImageHandle, 'ButtonDownFcn', @(src, event) app.imageButtonDown(src, event));
                fprintf('正常回调函数已恢复\n');
                app.StatusLabel.Text = '状态：测试完成，回调已恢复';
            end
            
            app.StatusLabel.Text = '状态：正在测试回调函数...';
        end

        % Button pushed function: AlternativeButton
        function AlternativeButtonPushed(app, event)
            fprintf('\n=== 启动替代鼠标检测方法 ===\n');
            
            if isempty(app.CurrentImage)
                app.StatusLabel.Text = '状态：请先加载图像';
                return;
            end
            
            % 停止之前的定时器（如果存在）
            if ~isempty(app.MouseTimer) && isvalid(app.MouseTimer)
                stop(app.MouseTimer);
                delete(app.MouseTimer);
            end
            
            % 初始化鼠标状态
            app.LastMouseState = false;
            
            % 创建定时器进行鼠标检测
            app.MouseTimer = timer('TimerFcn', @(~,~) app.checkMouseState(), ...
                                   'Period', 0.05, ...  % 20Hz 检测频率
                                   'ExecutionMode', 'fixedRate');
            start(app.MouseTimer);
            
            fprintf('替代鼠标检测已启动（20Hz）\n');
            fprintf('现在尝试在图像上按住鼠标左键并拖拽\n');
            app.StatusLabel.Text = '状态：替代检测模式已启动';
        end
        
        % Value changed function: BrushSizeSlider
        function BrushSizeSliderValueChanged(app, event)
            app.BrushSize = round(app.BrushSizeSlider.Value);
            app.BrushSizeLabel.Text = sprintf('画笔大小: %d', app.BrushSize);
            fprintf('画笔大小改变为: %d\n', app.BrushSize);
        end
    end

    % Private methods
    methods (Access = private)
        
        function displayImage(app)
            % 显示图像
            fprintf('=== 开始显示图像 ===\n');
            
            if ~isempty(app.CurrentImage)
                fprintf('图像尺寸: %d x %d x %d\n', size(app.CurrentImage));
                
                % 清空坐标轴
                cla(app.UIAxes);
                
                % 显示图像
                app.ImageHandle = imshow(app.CurrentImage, 'Parent', app.UIAxes);
                fprintf('图像句柄创建成功: %s\n', class(app.ImageHandle));
                
                % 设置坐标轴属性以支持鼠标交互
                app.UIAxes.Interactions = [];
                app.UIAxes.Toolbar = [];
                fprintf('坐标轴交互已禁用\n');
                
                % 方法1：设置 UIAxes 的回调函数（推荐用于 App Designer）
                app.UIAxes.ButtonDownFcn = @(src, event) app.axesButtonDown(src, event);
                fprintf('UIAxes ButtonDownFcn已设置\n');
                
                % 方法2：同时设置图像的回调函数作为备选
                set(app.ImageHandle, 'HitTest', 'on');
                set(app.ImageHandle, 'PickableParts', 'all');
                set(app.ImageHandle, 'ButtonDownFcn', @(src, event) app.imageButtonDown(src, event));
                fprintf('图像ButtonDownFcn已设置为备选\n');
                
                % 设置窗口级别的鼠标事件
                app.UIFigure.WindowButtonMotionFcn = @(src, event) app.mouseMove(src, event);
                app.UIFigure.WindowButtonUpFcn = @(src, event) app.mouseReleased(src, event);
                fprintf('窗口鼠标事件已设置\n');
                
                % 确保坐标轴设置正确
                axis(app.UIAxes, 'image');
                app.UIAxes.XLim = [0.5, size(app.CurrentImage, 2) + 0.5];
                app.UIAxes.YLim = [0.5, size(app.CurrentImage, 1) + 0.5];
                fprintf('坐标轴范围设置: X[%.1f, %.1f], Y[%.1f, %.1f]\n', ...
                    app.UIAxes.XLim(1), app.UIAxes.XLim(2), ...
                    app.UIAxes.YLim(1), app.UIAxes.YLim(2));
                
                % 方法3：使用更直接的事件绑定
                try
                    % 禁用默认的缩放和平移
                    disableDefaultInteractivity(app.UIAxes);
                    fprintf('已禁用默认交互\n');
                catch
                    fprintf('无法禁用默认交互（可能是版本问题）\n');
                end
                
                fprintf('=== 图像显示完成 ===\n');
            else
                fprintf('错误：当前图像为空\n');
            end
        end
        
        function initializeMask(app)
            % 初始化 mask
            if ~isempty(app.CurrentImage)
                [h, w, ~] = size(app.CurrentImage);
                app.MaskImage = zeros(h, w, 'logical');
                app.updateMaskDisplay();
            end
        end
        
        function updateMaskDisplay(app)
            % 更新 mask 显示
            if ~isempty(app.MaskImage) && isvalid(app.ImageHandle)
                % 删除之前的 mask 覆盖层
                if ~isempty(app.MaskHandle) && isvalid(app.MaskHandle)
                    delete(app.MaskHandle);
                end
                
                % 创建半透明的红色 mask 覆盖层
                hold(app.UIAxes, 'on');
                
                % 创建彩色 mask（红色半透明）
                [h, w] = size(app.MaskImage);
                maskRGB = zeros(h, w, 3);
                maskRGB(:,:,1) = double(app.MaskImage); % 红色通道
                
                % 显示半透明覆盖层
                app.MaskHandle = imshow(maskRGB, 'Parent', app.UIAxes);
                set(app.MaskHandle, 'AlphaData', double(app.MaskImage) * 0.4);
                
                hold(app.UIAxes, 'off');
            end
        end
        
        function axesButtonDown(app, src, event)
            % UIAxes 点击事件处理（主要方法）
            fprintf('\n*** UIAxes 被点击! ***\n');
            fprintf('源对象: %s\n', class(src));
            app.mousePressed(src, event);
        end
        
        function imageButtonDown(app, src, event)
            % 图像点击事件处理（备选方法）
            fprintf('\n*** 图像对象被点击! ***\n');
            fprintf('源对象: %s\n', class(src));
            app.mousePressed(src, event);
        end
        
        function mousePressed(app, src, event)
            % 鼠标按下事件
            fprintf('\n*** mousePressed 被调用! ***\n');
            fprintf('源对象类型: %s\n', class(src));
            if nargin > 2
                fprintf('事件类型: %s\n', class(event));
            end
            
            if ~isempty(app.CurrentImage)
                app.IsDrawing = true;
                fprintf('开始绘制模式...\n');
                
                % 获取当前鼠标位置
                try
                    pos = app.UIAxes.CurrentPoint;
                    fprintf('当前鼠标位置: [%.2f, %.2f]\n', pos(1,1), pos(1,2));
                    app.drawAtCurrentPosition();
                catch ME
                    fprintf('获取鼠标位置时出错: %s\n', ME.message);
                end
            else
                fprintf('警告：当前图像为空，无法绘制\n');
            end
        end
        
        function mouseMove(app, ~, ~)
            % 鼠标移动事件
            if app.IsDrawing && ~isempty(app.CurrentImage)
                fprintf('.'); % 简单的移动指示符
                app.drawAtCurrentPosition();
            end
        end
        
        function mouseReleased(app, ~, ~)
            % 鼠标释放事件
            if app.IsDrawing
                fprintf('\n*** 结束绘制 ***\n');
                app.IsDrawing = false;
            end
        end
        
        function drawAtCurrentPosition(app)
            % 在当前鼠标位置绘制
            try
                % 获取鼠标在坐标轴中的位置
                pos = app.UIAxes.CurrentPoint;
                x = round(pos(1,1));
                y = round(pos(1,2));
                
                fprintf('绘制位置: (%d, %d)\n', x, y);
                
                % 检查坐标是否在图像范围内
                [h, w, ~] = size(app.CurrentImage);
                fprintf('图像尺寸: %d x %d\n', h, w);
                
                if x >= 1 && x <= w && y >= 1 && y <= h
                    fprintf('坐标在有效范围内，开始绘制...\n');
                    
                    % 创建圆形画笔
                    [meshX, meshY] = meshgrid(1:w, 1:h);
                    distances = sqrt((meshX - x).^2 + (meshY - y).^2);
                    brushMask = distances <= app.BrushSize/2;
                    
                    % 计算受影响的像素数量
                    affectedPixels = sum(brushMask(:));
                    fprintf('画笔大小: %d, 受影响像素: %d\n', app.BrushSize, affectedPixels);
                    
                    % 更新 mask
                    oldMaskSum = sum(app.MaskImage(:));
                    app.MaskImage = app.MaskImage | brushMask;
                    newMaskSum = sum(app.MaskImage(:));
                    
                    fprintf('Mask像素变化: %d -> %d\n', oldMaskSum, newMaskSum);
                    
                    % 实时更新显示
                    app.updateMaskDisplay();
                    
                    % 强制刷新显示
                    drawnow;
                    fprintf('显示已更新\n');
                else
                    fprintf('坐标超出范围: (%d, %d) 不在 [1,%d] x [1,%d] 内\n', x, y, w, h);
                end
            catch ME
                % 调试信息
                fprintf('绘制错误: %s\n', ME.message);
                fprintf('错误堆栈:\n');
                for i = 1:length(ME.stack)
                    fprintf('  %s (行 %d)\n', ME.stack(i).name, ME.stack(i).line);
                end
            end
        end
        
        function loadDefaultImage(app)
            % 加载默认测试图像
            fprintf('\n=== 加载默认图像 ===\n');
            app.StatusLabel.Text = '状态：正在加载图像...';
            
            try
                % 尝试加载 MATLAB 自带图像
                app.CurrentImage = imread('peppers.png');
                fprintf('成功加载 peppers.png\n');
                app.StatusLabel.Text = '状态：已加载 peppers.png';
            catch
                try
                    % 尝试其他自带图像
                    app.CurrentImage = imread('cameraman.tif');
                    fprintf('成功加载 cameraman.tif\n');
                    app.StatusLabel.Text = '状态：已加载 cameraman.tif';
                catch
                    % 创建一个简单的测试图像
                    fprintf('创建测试图像\n');
                    [X, Y] = meshgrid(1:300, 1:200);
                    testImg = uint8(127 + 50 * sin(X/20) .* cos(Y/15));
                    app.CurrentImage = repmat(testImg, [1, 1, 3]);
                    app.StatusLabel.Text = '状态：已创建测试图像';
                end
            end
            
            % 显示图像并初始化 mask
            app.displayImage();
            app.initializeMask();
            
            fprintf('图像加载完成。请点击"测试回调"按钮检查鼠标事件\n');
            fprintf('然后尝试在图像上点击拖拽进行绘制\n');
            app.StatusLabel.Text = [app.StatusLabel.Text, ' - 点击测试回调按钮'];
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 800 600];
            app.UIFigure.Name = 'Mask Generator (调试版本)';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [50 120 500 400];

            % Create LoadImageButton
            app.LoadImageButton = uibutton(app.UIFigure, 'push');
            app.LoadImageButton.ButtonPushedFcn = createCallbackFcn(app, @LoadImageButtonPushed, true);
            app.LoadImageButton.Position = [600 480 120 30];
            app.LoadImageButton.Text = '加载图像';

            % Create ClearMaskButton
            app.ClearMaskButton = uibutton(app.UIFigure, 'push');
            app.ClearMaskButton.ButtonPushedFcn = createCallbackFcn(app, @ClearMaskButtonPushed, true);
            app.ClearMaskButton.Position = [600 440 120 30];
            app.ClearMaskButton.Text = '清除 Mask';

            % Create SaveMaskButton
            app.SaveMaskButton = uibutton(app.UIFigure, 'push');
            app.SaveMaskButton.ButtonPushedFcn = createCallbackFcn(app, @SaveMaskButtonPushed, true);
            app.SaveMaskButton.Position = [600 400 120 30];
            app.SaveMaskButton.Text = '保存 Mask';

            % Create TestButton
            app.TestButton = uibutton(app.UIFigure, 'push');
            app.TestButton.ButtonPushedFcn = createCallbackFcn(app, @TestButtonPushed, true);
            app.TestButton.Position = [600 360 120 30];
            app.TestButton.Text = '测试回调';
            app.TestButton.BackgroundColor = [1 0.8 0.8]; % 浅红色背景

            % Create BrushSizeLabel
            app.BrushSizeLabel = uilabel(app.UIFigure);
            app.BrushSizeLabel.Position = [600 320 120 22];
            app.BrushSizeLabel.Text = '画笔大小: 10';

            % Create BrushSizeSlider
            app.BrushSizeSlider = uislider(app.UIFigure);
            app.BrushSizeSlider.Limits = [1 50];
            app.BrushSizeSlider.Value = 10;
            app.BrushSizeSlider.ValueChangedFcn = createCallbackFcn(app, @BrushSizeSliderValueChanged, true);
            app.BrushSizeSlider.Position = [600 300 120 3];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [50 80 700 22];
            app.StatusLabel.Text = '状态：准备就绪';
            app.StatusLabel.FontColor = [0 0.6 0];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MaskGeneratorApp

            % Create UIFigure and components
            createComponents(app);

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end