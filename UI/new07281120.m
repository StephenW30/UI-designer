classdef ImprovedMaskGeneratorApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        UIAxes                  matlab.ui.control.UIAxes
        LoadImageButton         matlab.ui.control.Button
        ClearMaskButton         matlab.ui.control.Button
        SaveMaskButton          matlab.ui.control.Button
        ManualDrawButton        matlab.ui.control.Button
        ModeButtonGroup         matlab.ui.container.ButtonGroup
        DragModeButton          matlab.ui.control.RadioButton
        PolygonModeButton       matlab.ui.control.RadioButton
        CancelPolygonButton     matlab.ui.control.Button
        TestClickButton         matlab.ui.control.Button
        BrushSizeSlider         matlab.ui.control.Slider
        BrushSizeLabel          matlab.ui.control.Label
        StatusLabel             matlab.ui.control.Label
        XEditField              matlab.ui.control.NumericEditField
        YEditField              matlab.ui.control.NumericEditField
        XLabel                  matlab.ui.control.Label
        YLabel                  matlab.ui.control.Label
    end
    
    % Private properties
    properties (Access = private)
        CurrentImage            % 当前显示的图像
        MaskImage              % 当前的 mask 图像
        BrushSize              % 画笔大小
        ImageHandle            % 图像句柄
        MaskHandle             % mask 覆盖层句柄
        
        % 绘制模式相关
        DrawingMode            % 绘制模式：'drag' 或 'polygon'
        IsDrawing              % 是否正在拖拽绘制
        
        % 多边形相关属性
        PolygonPoints          % 多边形顶点坐标 [x1 y1; x2 y2; ...]
        PolygonHandles         % 多边形可视化句柄
        IsPolygonActive        % 是否正在绘制多边形
        PolygonCloseTolerance  % 闭合多边形的距离容差
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % 初始化参数
            app.BrushSize = 10;
            app.BrushSizeSlider.Value = 10;
            app.IsDrawing = false;
            
            % 初始化多边形相关参数
            app.DrawingMode = 'drag';  % 默认拖拽模式
            app.PolygonPoints = [];
            app.PolygonHandles = [];
            app.IsPolygonActive = false;
            app.PolygonCloseTolerance = 10;  % 像素
            
            % 设置坐标轴属性
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            app.UIAxes.Box = 'on';
            app.UIAxes.HitTest = 'on';
            app.UIAxes.PickableParts = 'all';
            app.UIAxes.Interactions = [];
            app.UIAxes.Toolbar.Visible = 'off';
            title(app.UIAxes, '改进版拖拽 + 多边形 Mask 生成器');
            
            % 初始化用户数据
            app.UIFigure.UserData = struct();
            app.UIFigure.UserData.brushing = false;
            
            % 自动加载测试图像
            app.loadDefaultImage();
            
            fprintf('\n=== 改进版拖拽 + 多边形 Mask 生成器 ===\n');
            fprintf('功能说明：\n');
            fprintf('1. 拖拽模式：鼠标点击拖拽绘制\n');
            fprintf('2. 多边形模式：点击多个点形成多边形，双击完成\n');
            fprintf('3. 手动输入坐标绘制\n');
            fprintf('4. 键盘快捷键绘制\n');
        end

        % Button pushed function: LoadImageButton
        function LoadImageButtonPushed(app, event)
            [filename, pathname] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tiff', '图像文件'});
            if filename ~= 0
                app.CurrentImage = imread(fullfile(pathname, filename));
                app.displayImage();
                app.initializeMask();
                app.StatusLabel.Text = '状态：图像已加载';
            end
        end

        % Button pushed function: ClearMaskButton
        function ClearMaskButtonPushed(app, event)
            if ~isempty(app.CurrentImage)
                app.initializeMask();
                app.updateMaskDisplay();
                app.cancelCurrentPolygon();  % 同时清除当前多边形
                app.StatusLabel.Text = '状态：Mask 和多边形已清除';
            end
        end

        % Button pushed function: SaveMaskButton
        function SaveMaskButtonPushed(app, event)
            if ~isempty(app.MaskImage)
                [filename, pathname] = uiputfile({'*.png', 'PNG 文件'}, 'mask.png');
                if filename ~= 0
                    imwrite(uint8(app.MaskImage * 255), fullfile(pathname, filename));
                    app.StatusLabel.Text = '状态：Mask 已保存';
                end
            end
        end

        % Button pushed function: ManualDrawButton
        function ManualDrawButtonPushed(app, event)
            if isempty(app.CurrentImage)
                app.StatusLabel.Text = '状态：请先加载图像';
                return;
            end
            
            x = round(app.XEditField.Value);
            y = round(app.YEditField.Value);
            
            if x < 1 || y < 1 || x > size(app.CurrentImage, 2) || y > size(app.CurrentImage, 1)
                app.StatusLabel.Text = sprintf('状态：坐标超出范围 [1,%d] x [1,%d]', ...
                    size(app.CurrentImage, 2), size(app.CurrentImage, 1));
                return;
            end
            
            app.drawAtPosition(x, y);
            app.StatusLabel.Text = sprintf('状态：在 (%d, %d) 处绘制完成', x, y);
        end

        % Mode selection change
        function ModeButtonGroupSelectionChanged(app, event)
            selectedButton = app.ModeButtonGroup.SelectedObject;
            
            if selectedButton == app.DragModeButton
                app.DrawingMode = 'drag';
                app.StatusLabel.Text = '状态：切换到拖拽模式';
                fprintf('切换到拖拽模式\n');
                app.cancelCurrentPolygon();
                app.setupDragMode();
            elseif selectedButton == app.PolygonModeButton
                app.DrawingMode = 'polygon';
                app.StatusLabel.Text = '状态：切换到多边形模式 - 开始点击顶点';
                fprintf('切换到多边形模式\n');
                app.setupPolygonMode();
            end
        end

        % Button pushed function: CancelPolygonButton
        function CancelPolygonButtonPushed(app, event)
            app.cancelCurrentPolygon();
            app.StatusLabel.Text = '状态：已取消当前多边形';
            fprintf('取消当前多边形\n');
        end

        % Button pushed function: TestClickButton
        function TestClickButtonPushed(app, event)
            if isempty(app.CurrentImage)
                app.StatusLabel.Text = '请先加载图像';
                return;
            end
            
            % 设置测试回调
            app.UIAxes.ButtonDownFcn = @(src,event) app.testClickCallback(event);
            app.StatusLabel.Text = '测试模式：点击图像测试鼠标事件';
            fprintf('测试模式启动，点击图像\n');
        end

        % Value changed function: BrushSizeSlider
        function BrushSizeSliderValueChanged(app, event)
            app.BrushSize = round(app.BrushSizeSlider.Value);
            app.BrushSizeLabel.Text = sprintf('画笔大小: %d', app.BrushSize);
        end

        % Key press function: UIFigure
        function UIFigureKeyPress(app, event)
            if strcmp(event.Key, 'space') && ~isempty(app.CurrentImage)
                % 空格键：在图像中心绘制
                x = round(size(app.CurrentImage, 2) / 2);
                y = round(size(app.CurrentImage, 1) / 2);
                app.drawAtPosition(x, y);
                app.StatusLabel.Text = sprintf('状态：在中心 (%d, %d) 绘制', x, y);
            elseif strcmp(event.Key, 'r')
                % R键：随机位置绘制
                if ~isempty(app.CurrentImage)
                    x = randi(size(app.CurrentImage, 2));
                    y = randi(size(app.CurrentImage, 1));
                    app.drawAtPosition(x, y);
                    app.StatusLabel.Text = sprintf('状态：在随机位置 (%d, %d) 绘制', x, y);
                end
            end
        end
    end

    % Private methods
    methods (Access = private)
        
        function displayImage(app)
            fprintf('显示图像...\n');
            if ~isempty(app.CurrentImage)
                % 清空并显示图像
                cla(app.UIAxes);
                app.ImageHandle = imshow(app.CurrentImage, 'Parent', app.UIAxes);
                
                % 设置坐标轴
                axis(app.UIAxes, 'image');
                
                % 确保鼠标交互正确设置
                app.UIAxes.HitTest = 'on';
                app.UIAxes.PickableParts = 'all';
                app.UIAxes.Interactions = [];
                app.UIAxes.Toolbar.Visible = 'off';
                
                % 根据当前模式设置相应的回调
                if strcmp(app.DrawingMode, 'drag')
                    app.setupDragMode();
                elseif strcmp(app.DrawingMode, 'polygon')
                    app.setupPolygonMode();
                end
                
                fprintf('图像显示完成，图像尺寸: %d x %d\n', size(app.CurrentImage, 1), size(app.CurrentImage, 2));
            end
        end
        
        function setupDragMode(app)
            % 设置拖拽模式的回调
            if ~isempty(app.CurrentImage)
                % 清除现有回调
                app.UIAxes.ButtonDownFcn = [];
                app.UIFigure.WindowButtonMotionFcn = [];
                app.UIFigure.WindowButtonUpFcn = [];
                
                % 设置拖拽回调
                app.UIAxes.ButtonDownFcn = @(src,event) app.startDragDrawing(event);
                app.UIFigure.WindowButtonMotionFcn = @(src,event) app.continueDragDrawing(event);
                app.UIFigure.WindowButtonUpFcn = @(src,event) app.endDragDrawing(event);
                
                fprintf('拖拽模式回调已设置\n');
            end
        end
        
        function setupPolygonMode(app)
            % 设置多边形模式的回调
            if ~isempty(app.CurrentImage)
                % 清除现有回调
                app.UIAxes.ButtonDownFcn = [];
                app.UIFigure.WindowButtonMotionFcn = [];
                app.UIFigure.WindowButtonUpFcn = [];
                
                % 设置多边形回调
                app.UIAxes.ButtonDownFcn = @(src,event) app.addPolygonPoint(event);
                
                fprintf('多边形模式回调已设置\n');
            end
        end
        
        function testClickCallback(app, event)
            try
                clickPos = event.IntersectionPoint(1:2);
                app.StatusLabel.Text = sprintf('✅ 点击检测成功！位置: (%.1f, %.1f)', clickPos(1), clickPos(2));
                fprintf('鼠标点击检测成功: (%.1f, %.1f)\n', clickPos(1), clickPos(2));
                
                % 恢复当前模式的回调
                if strcmp(app.DrawingMode, 'drag')
                    app.setupDragMode();
                else
                    app.setupPolygonMode();
                end
            catch ME
                app.StatusLabel.Text = sprintf('❌ 点击检测失败: %s', ME.message);
                fprintf('鼠标点击检测失败: %s\n', ME.message);
            end
        end
        
        function startDragDrawing(app, event)
            if ~isempty(app.CurrentImage)
                try
                    clickPos = event.IntersectionPoint(1:2);
                    app.IsDrawing = true;
                    app.UIFigure.UserData.brushing = true;
                    
                    fprintf('\n*** 开始拖拽绘制 ***\n');
                    app.StatusLabel.Text = '状态：正在拖拽绘制...';
                    
                    % 执行初始绘制
                    app.performDragDrawing(clickPos);
                catch ME
                    app.StatusLabel.Text = sprintf('拖拽开始错误: %s', ME.message);
                    fprintf('拖拽开始错误: %s\n', ME.message);
                end
            end
        end
        
        function continueDragDrawing(app, event)
            if app.IsDrawing && app.UIFigure.UserData.brushing && ~isempty(app.CurrentImage)
                try
                    % 获取当前鼠标位置
                    currentPoint = app.UIAxes.CurrentPoint;
                    if ~isempty(currentPoint)
                        clickPos = currentPoint(1, 1:2);
                        app.performDragDrawing(clickPos);
                    end
                catch ME
                    fprintf('拖拽继续错误: %s\n', ME.message);
                end
            end
        end
        
        function endDragDrawing(app, event)
            if app.IsDrawing
                app.IsDrawing = false;
                app.UIFigure.UserData.brushing = false;
                fprintf('\n*** 拖拽绘制结束 ***\n');
                app.StatusLabel.Text = '状态：拖拽绘制完成';
            end
        end
        
        function performDragDrawing(app, clickPos)
            try
                % 转换为像素坐标
                x = round(clickPos(1));
                y = round(clickPos(2));
                
                % 检查边界
                [h, w, ~] = size(app.CurrentImage);
                if x >= 1 && x <= w && y >= 1 && y <= h
                    app.drawAtPosition(x, y);
                    
                    % 更新编辑框
                    app.XEditField.Value = x;
                    app.YEditField.Value = y;
                end
            catch ME
                fprintf('拖拽绘制错误: %s\n', ME.message);
            end
        end
        
        function addPolygonPoint(app, event)
            persistent lastClickTime;
            
            if ~isempty(app.CurrentImage)
                try
                    clickPos = event.IntersectionPoint(1:2);
                    x = round(clickPos(1));
                    y = round(clickPos(2));
                    
                    % 检查边界
                    [h, w, ~] = size(app.CurrentImage);
                    if x < 1 || x > w || y < 1 || y > h
                        return;
                    end
                    
                    currentTime = now;
                    
                    % 检测双击
                    if ~isempty(lastClickTime)
                        timeDiff = (currentTime - lastClickTime) * 24 * 3600;
                        if timeDiff < 0.5 && size(app.PolygonPoints, 1) >= 3
                            % 双击，完成多边形
                            app.finishPolygon();
                            lastClickTime = [];
                            return;
                        end
                    end
                    
                    % 检查是否点击起始点附近（闭合）
                    if size(app.PolygonPoints, 1) >= 3
                        startPoint = app.PolygonPoints(1, :);
                        distance = sqrt((x - startPoint(1))^2 + (y - startPoint(2))^2);
                        if distance <= app.PolygonCloseTolerance
                            app.finishPolygon();
                            lastClickTime = [];
                            return;
                        end
                    end
                    
                    % 添加新点
                    app.PolygonPoints = [app.PolygonPoints; x, y];
                    lastClickTime = currentTime;
                    
                    fprintf('添加多边形顶点 %d: (%d, %d)\n', size(app.PolygonPoints, 1), x, y);
                    
                    % 更新可视化
                    app.updatePolygonVisualization();
                    
                    % 更新状态
                    if size(app.PolygonPoints, 1) >= 3
                        app.StatusLabel.Text = sprintf('状态：已添加 %d 个顶点 - 双击或点击起始点完成', size(app.PolygonPoints, 1));
                    else
                        app.StatusLabel.Text = sprintf('状态：已添加 %d 个顶点 - 至少需要3个点', size(app.PolygonPoints, 1));
                    end
                    
                    % 更新编辑框
                    app.XEditField.Value = x;
                    app.YEditField.Value = y;
                    
                catch ME
                    app.StatusLabel.Text = sprintf('添加多边形点错误: %s', ME.message);
                    fprintf('添加多边形点错误: %s\n', ME.message);
                end
            end
        end
        
        function finishPolygon(app)
            try
                if size(app.PolygonPoints, 1) < 3
                    app.StatusLabel.Text = '多边形顶点不足3个';
                    return;
                end
                
                % 获取图像尺寸
                [h, w, ~] = size(app.CurrentImage);
                
                % 使用 poly2mask 生成多边形 mask
                x_coords = app.PolygonPoints(:, 1);
                y_coords = app.PolygonPoints(:, 2);
                
                % 确保坐标在图像范围内
                x_coords = max(1, min(w, x_coords));
                y_coords = max(1, min(h, y_coords));
                
                % 生成多边形 mask
                polygonMask = poly2mask(x_coords, y_coords, h, w);
                
                % 将多边形 mask 添加到现有 mask
                app.MaskImage = app.MaskImage | polygonMask;
                
                % 更新显示
                app.updateMaskDisplay();
                
                % 清理多边形
                app.cancelCurrentPolygon();
                
                fprintf('多边形 mask 生成完成，包含 %d 个像素\n', sum(polygonMask(:)));
                app.StatusLabel.Text = sprintf('状态：多边形完成，包含 %d 个像素', sum(polygonMask(:)));
                
            catch ME
                app.StatusLabel.Text = sprintf('完成多边形错误: %s', ME.message);
                fprintf('完成多边形错误: %s\n', ME.message);
            end
        end
        
        function updatePolygonVisualization(app)
            try
                % 删除之前的可视化
                app.clearPolygonVisualization();
                
                if isempty(app.PolygonPoints)
                    return;
                end
                
                hold(app.UIAxes, 'on');
                
                % 绘制顶点 - 1个像素大小
                app.PolygonHandles.points = plot(app.UIAxes, ...
                    app.PolygonPoints(:, 1), app.PolygonPoints(:, 2), ...
                    'ro', 'MarkerSize', 1, 'MarkerFaceColor', 'red');
                
                % 绘制起始点（特殊标记）- 1个像素大小
                if size(app.PolygonPoints, 1) >= 1
                    app.PolygonHandles.startPoint = plot(app.UIAxes, ...
                        app.PolygonPoints(1, 1), app.PolygonPoints(1, 2), ...
                        'go', 'MarkerSize', 1, 'MarkerFaceColor', 'green');
                end
                
                % 绘制连线
                if size(app.PolygonPoints, 1) >= 2
                    app.PolygonHandles.lines = plot(app.UIAxes, ...
                        app.PolygonPoints(:, 1), app.PolygonPoints(:, 2), ...
                        'b-', 'LineWidth', 1);
                end
                
                % 如果有3个或更多点，绘制预览闭合线
                if size(app.PolygonPoints, 1) >= 3
                    x_preview = [app.PolygonPoints(end, 1), app.PolygonPoints(1, 1)];
                    y_preview = [app.PolygonPoints(end, 2), app.PolygonPoints(1, 2)];
                    app.PolygonHandles.previewLine = plot(app.UIAxes, ...
                        x_preview, y_preview, 'g--', 'LineWidth', 1);
                end
                
                hold(app.UIAxes, 'off');
                
            catch ME
                fprintf('更新多边形可视化错误: %s\n', ME.message);
            end
        end
        
        function clearPolygonVisualization(app)
            try
                if ~isempty(app.PolygonHandles) && isstruct(app.PolygonHandles)
                    fields = fieldnames(app.PolygonHandles);
                    for i = 1:length(fields)
                        h = app.PolygonHandles.(fields{i});
                        if isvalid(h)
                            delete(h);
                        end
                    end
                end
                app.PolygonHandles = [];
            catch ME
                fprintf('清除多边形可视化错误: %s\n', ME.message);
            end
        end
        
        function cancelCurrentPolygon(app)
            app.PolygonPoints = [];
            app.IsPolygonActive = false;
            app.clearPolygonVisualization();
        end
        
        function initializeMask(app)
            if ~isempty(app.CurrentImage)
                [h, w, ~] = size(app.CurrentImage);
                app.MaskImage = zeros(h, w, 'logical');
                app.updateMaskDisplay();
                fprintf('Mask 已初始化: %d x %d\n', h, w);
            end
        end
        
        function updateMaskDisplay(app)
            if ~isempty(app.MaskImage) && isvalid(app.ImageHandle)
                % 删除之前的 mask
                if ~isempty(app.MaskHandle) && isvalid(app.MaskHandle)
                    delete(app.MaskHandle);
                end
                
                % 创建红色半透明 mask
                hold(app.UIAxes, 'on');
                [h, w] = size(app.MaskImage);
                maskRGB = zeros(h, w, 3);
                maskRGB(:,:,1) = double(app.MaskImage);
                
                app.MaskHandle = imshow(maskRGB, 'Parent', app.UIAxes);
                set(app.MaskHandle, 'AlphaData', double(app.MaskImage) * 0.5);
                hold(app.UIAxes, 'off');
            end
        end
        
        function drawAtPosition(app, x, y)
            if isempty(app.CurrentImage)
                return;
            end
            
            [h, w, ~] = size(app.CurrentImage);
            if x >= 1 && x <= w && y >= 1 && y <= h
                % 创建圆形画笔
                [meshX, meshY] = meshgrid(1:w, 1:h);
                distances = sqrt((meshX - x).^2 + (meshY - y).^2);
                brushMask = distances <= app.BrushSize/2;
                
                % 更新 mask
                app.MaskImage = app.MaskImage | brushMask;
                
                % 更新显示
                app.updateMaskDisplay();
                
                fprintf('在位置 (%d, %d) 绘制了 %d 个像素\n', x, y, sum(brushMask(:)));
            end
        end
        
        function loadDefaultImage(app)
            fprintf('加载默认图像...\n');
            try
                app.CurrentImage = imread('peppers.png');
                app.StatusLabel.Text = '状态：已加载 peppers.png - 拖拽模式';
            catch
                try
                    app.CurrentImage = imread('cameraman.tif');
                    app.StatusLabel.Text = '状态：已加载 cameraman.tif - 拖拽模式';
                catch
                    % 创建测试图像
                    [X, Y] = meshgrid(1:300, 1:200);
                    testImg = uint8(127 + 50 * sin(X/20) .* cos(Y/15));
                    app.CurrentImage = repmat(testImg, [1, 1, 3]);
                    app.StatusLabel.Text = '状态：已创建测试图像 - 拖拽模式';
                end
            end
            
            app.displayImage();
            app.initializeMask();
            
            % 设置默认坐标
            app.XEditField.Value = round(size(app.CurrentImage, 2) / 2);
            app.YEditField.Value = round(size(app.CurrentImage, 1) / 2);
            
            fprintf('默认图像加载完成\n');
            fprintf('=== 使用方法 ===\n');
            fprintf('1. 拖拽模式：点击并拖拽进行连续绘制\n');
            fprintf('2. 多边形模式：点击多个顶点，双击或点击起始点闭合\n');
            fprintf('3. 手动绘制：输入坐标后点击按钮\n');
            fprintf('4. 键盘快捷键：空格键（中心），R键（随机）\n');
            fprintf('5. 测试按钮：验证鼠标事件是否正常工作\n');
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1000 650];
            app.UIFigure.Name = '改进版拖拽 + 多边形 Mask 生成器';
            app.UIFigure.KeyPressFcn = createCallbackFcn(app, @UIFigureKeyPress, true);

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [50 150 550 450];

            % Create LoadImageButton
            app.LoadImageButton = uibutton(app.UIFigure, 'push');
            app.LoadImageButton.ButtonPushedFcn = createCallbackFcn(app, @LoadImageButtonPushed, true);
            app.LoadImageButton.Position = [650 580 120 30];
            app.LoadImageButton.Text = '加载图像';

            % Create ClearMaskButton
            app.ClearMaskButton = uibutton(app.UIFigure, 'push');
            app.ClearMaskButton.ButtonPushedFcn = createCallbackFcn(app, @ClearMaskButtonPushed, true);
            app.ClearMaskButton.Position = [650 540 120 30];
            app.ClearMaskButton.Text = '清除 Mask';

            % Create SaveMaskButton
            app.SaveMaskButton = uibutton(app.UIFigure, 'push');
            app.SaveMaskButton.Position = [650 500 120 30];
            app.SaveMaskButton.Text = '保存 Mask';
            app.SaveMaskButton.ButtonPushedFcn = createCallbackFcn(app, @SaveMaskButtonPushed, true);

            % Create Mode Selection Button Group
            app.ModeButtonGroup = uibuttongroup(app.UIFigure);
            app.ModeButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @ModeButtonGroupSelectionChanged, true);
            app.ModeButtonGroup.Title = '绘制模式';
            app.ModeButtonGroup.Position = [650 440 120 60];

            % Create DragModeButton
            app.DragModeButton = uiradiobutton(app.ModeButtonGroup);
            app.DragModeButton.Text = '拖拽模式';
            app.DragModeButton.Position = [10 30 100 22];
            app.DragModeButton.Value = true;

            % Create PolygonModeButton
            app.PolygonModeButton = uiradiobutton(app.ModeButtonGroup);
            app.PolygonModeButton.Text = '多边形模式';
            app.PolygonModeButton.Position = [10 8 100 22];

            % Create CancelPolygonButton
            app.CancelPolygonButton = uibutton(app.UIFigure, 'push');
            app.CancelPolygonButton.ButtonPushedFcn = createCallbackFcn(app, @CancelPolygonButtonPushed, true);
            app.CancelPolygonButton.Position = [650 400 120 30];
            app.CancelPolygonButton.Text = '取消多边形';
            app.CancelPolygonButton.BackgroundColor = [1 0.8 0.8];

            % Create TestClickButton
            app.TestClickButton = uibutton(app.UIFigure, 'push');
            app.TestClickButton.ButtonPushedFcn = createCallbackFcn(app, @TestClickButtonPushed, true);
            app.TestClickButton.Position = [650 360 120 30];
            app.TestClickButton.Text = '测试点击';
            app.TestClickButton.BackgroundColor = [0.8 0.8 1];

            % Create ManualDrawButton
            app.ManualDrawButton = uibutton(app.UIFigure, 'push');
            app.ManualDrawButton.ButtonPushedFcn = createCallbackFcn(app, @ManualDrawButtonPushed, true);
            app.ManualDrawButton.Position = [650 320 120 30];
            app.ManualDrawButton.Text = '手动绘制';
            app.ManualDrawButton.BackgroundColor = [0.8 1 0.8];

            % Create coordinate input fields
            app.XLabel = uilabel(app.UIFigure);
            app.XLabel.Position = [650 290 30 22];
            app.XLabel.Text = 'X:';

            app.XEditField = uieditfield(app.UIFigure, 'numeric');
            app.XEditField.Position = [680 290 40 22];
            app.XEditField.Value = 150;

            app.YLabel = uilabel(app.UIFigure);
            app.YLabel.Position = [730 290 30 22];
            app.YLabel.Text = 'Y:';

            app.YEditField = uieditfield(app.UIFigure, 'numeric');
            app.YEditField.Position = [760 290 40 22];
            app.YEditField.Value = 100;

            % Create BrushSizeLabel
            app.BrushSizeLabel = uilabel(app.UIFigure);
            app.BrushSizeLabel.Position = [650 250 120 22];
            app.BrushSizeLabel.Text = '画笔大小: 10';

            % Create BrushSizeSlider
            app.BrushSizeSlider = uislider(app.UIFigure);
            app.BrushSizeSlider.Limits = [1 50];
            app.BrushSizeSlider.Value = 10;
            app.BrushSizeSlider.ValueChangedFcn = createCallbackFcn(app, @BrushSizeSliderValueChanged, true);
            app.BrushSizeSlider.Position = [650 230 120 3];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [50 100 900 30];
            app.StatusLabel.Text = '状态：拖拽模式 - 可以拖拽绘制或切换到多边形模式';
            app.StatusLabel.FontColor = [0 0.6 0];
            app.StatusLabel.FontSize = 12;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ImprovedMaskGeneratorApp

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
            % 清理多边形可视化
            app.clearPolygonVisualization();
            
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end