classdef WaferMapAnnotator < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainGrid                    matlab.ui.container.GridLayout
        ControlPanel                matlab.ui.container.Panel
        ControlGrid                 matlab.ui.container.GridLayout
        
        % Hazemap Panel (Left)
        HazemapPanel                matlab.ui.container.Panel
        HazemapGrid                 matlab.ui.container.GridLayout
        HazemapUIAxes               matlab.ui.control.UIAxes
        
        % Annotation Panel (Right)
        AnnotationPanel             matlab.ui.container.Panel
        AnnotationGrid              matlab.ui.container.GridLayout
        AnnotationUIAxes            matlab.ui.control.UIAxes
        
        StatusPanel                 matlab.ui.container.Panel
        StatusGrid                  matlab.ui.container.GridLayout
        StatusLabel                 matlab.ui.control.Label
        
        % Display Settings Panel
        DisplayPanel                matlab.ui.container.Panel
        DisplayGrid                 matlab.ui.container.GridLayout
        PlotInMmCheckBox           matlab.ui.control.CheckBox
        FlipVerticalCheckBox       matlab.ui.control.CheckBox
        PixelSizeEditField         matlab.ui.control.NumericEditField
        PixelSizeLabel             matlab.ui.control.Label
        WaferSizeEditField         matlab.ui.control.NumericEditField
        WaferSizeLabel             matlab.ui.control.Label
        
        % Image Enhancement Panel
        EnhancementPanel           matlab.ui.container.Panel
        EnhancementGrid            matlab.ui.container.GridLayout
        LowClipSlider              matlab.ui.control.Slider
        LowClipLabel               matlab.ui.control.Label
        LowClipValueLabel          matlab.ui.control.Label
        HighClipSlider             matlab.ui.control.Slider
        HighClipLabel              matlab.ui.control.Label
        HighClipValueLabel         matlab.ui.control.Label
        ResetClipButton            matlab.ui.control.Button
        AutoScaleButton            matlab.ui.control.Button
        
        % Annotation Controls Panel
        AnnotationControlsPanel    matlab.ui.container.Panel
        AnnotationControlsGrid     matlab.ui.container.GridLayout
        BrushSizeSlider           matlab.ui.control.Slider
        BrushSizeLabel            matlab.ui.control.Label
        BrushModeButton           matlab.ui.control.StateButton
        PolygonModeButton         matlab.ui.control.StateButton
        ClearMaskButton           matlab.ui.control.Button
        TestClickButton           matlab.ui.control.Button
        UndoButton                matlab.ui.control.Button
        RedoButton                matlab.ui.control.Button
        CancelPolygonButton       matlab.ui.control.Button
        
        % Label Management Panel
        LabelPanel                 matlab.ui.container.Panel
        LabelGrid                  matlab.ui.container.GridLayout
        LabelListBox              matlab.ui.control.ListBox
        AddLabelButton            matlab.ui.control.Button
        DeleteLabelButton         matlab.ui.control.Button
        CurrentLabelDropDown      matlab.ui.control.DropDown
        
        % File Management Panel
        FilePanel                  matlab.ui.container.Panel
        FileGrid                   matlab.ui.container.GridLayout
        SelectFolderButton        matlab.ui.control.Button
        PreviousImageButton       matlab.ui.control.Button
        NextImageButton           matlab.ui.control.Button
        CurrentFileLabel          matlab.ui.control.Label
        SaveAnnotationButton      matlab.ui.control.Button
    end

    % Private properties
    properties (Access = private)
        % Data properties
        originalMap                % Original image data
        workingMap                % Working copy for display
        validData                  % Valid data points for percentile calculation
        currentImageIndex = 1      % Current image index
        imageFiles = {}            % List of image files
        selectedFolder = ''        % Currently selected folder
        
        % Display properties
        pixelSizeMm = 0.1         % Pixel size in mm
        waferSizeMM = 150         % Wafer size in mm
        flipVertical = true       % Flip image vertically
        bPlotInMm = false         % Plot in mm units
        
        % Annotation properties
        brushMode = false         % Brush annotation mode
        polygonMode = false       % Polygon annotation mode
        brushSize = 3             % Brush size for annotation
        currentLabel = 'PL Star'   % Current selected label
        labelColors               % Colors for each label
        annotationData            % Annotation mask data for each label
        combinedMask              % Combined mask from all labels
        
        % Drawing state (borrowed from DragMaskGeneratorApp)
        IsDrawing = false         % Whether currently drawing
        IsInteractiveMode = false % Whether in interactive mode
        
        % Polygon properties (improved from DragMaskGeneratorApp)
        PolygonPoints = []        % Points for polygon annotation
        PolygonHandles = []       % Handles for polygon visualization
        IsPolygonActive = false   % Whether polygon is being drawn
        PolygonCloseTolerance = 10 % Distance tolerance for closing polygon
        
        % Image handles
        hazemapImageHandle        % Handle to the hazemap displayed image
        annotationImageHandle     % Handle to the annotation displayed image
        
        % History for undo/redo
        annotationHistory = {}    % History of annotation states
        historyIndex = 0          % Current position in history
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1400 800];
            app.UIFigure.Name = 'Wafer Map Annotator (Enhanced - Zoom Fixed + Smart Polygon Controls)';
            app.UIFigure.Resize = 'on';

            % Create MainGrid - 3 columns: Hazemap, Annotation Mask, Control Panel
            app.MainGrid = uigridlayout(app.UIFigure);
            app.MainGrid.ColumnWidth = {'1x', '1x', 350};
            app.MainGrid.RowHeight = {'1x', 40};

            % Create HazemapPanel (Left)
            app.HazemapPanel = uipanel(app.MainGrid);
            app.HazemapPanel.Title = 'Hazemap Display (Click here to annotate)';
            app.HazemapPanel.Layout.Row = 1;
            app.HazemapPanel.Layout.Column = 1;

            % Create HazemapGrid
            app.HazemapGrid = uigridlayout(app.HazemapPanel);
            app.HazemapGrid.RowHeight = {'1x'};
            app.HazemapGrid.ColumnWidth = {'1x'};

            % Create HazemapUIAxes
            app.HazemapUIAxes = uiaxes(app.HazemapGrid);
            app.HazemapUIAxes.Layout.Row = 1;
            app.HazemapUIAxes.Layout.Column = 1;
            app.HazemapUIAxes.XLabel.String = 'X (pixels)';
            app.HazemapUIAxes.YLabel.String = 'Y (pixels)';
            
            % 修复：保持默认的交互功能，不移除ticks
            app.HazemapUIAxes.Box = 'on';
            title(app.HazemapUIAxes, 'Hazemap');

            % Create AnnotationPanel (Center)
            app.AnnotationPanel = uipanel(app.MainGrid);
            app.AnnotationPanel.Title = 'Annotation Mask (View Only)';
            app.AnnotationPanel.Layout.Row = 1;
            app.AnnotationPanel.Layout.Column = 2;

            % Create AnnotationGrid
            app.AnnotationGrid = uigridlayout(app.AnnotationPanel);
            app.AnnotationGrid.RowHeight = {'1x'};
            app.AnnotationGrid.ColumnWidth = {'1x'};

            % Create AnnotationUIAxes
            app.AnnotationUIAxes = uiaxes(app.AnnotationGrid);
            app.AnnotationUIAxes.Layout.Row = 1;
            app.AnnotationUIAxes.Layout.Column = 1;
            app.AnnotationUIAxes.XLabel.String = 'X (pixels)';
            app.AnnotationUIAxes.YLabel.String = 'Y (pixels)';
            title(app.AnnotationUIAxes, 'Annotation Mask');

            % Create ControlPanel (Right)
            app.ControlPanel = uipanel(app.MainGrid);
            app.ControlPanel.Title = 'Control Panel';
            app.ControlPanel.Layout.Row = 1;
            app.ControlPanel.Layout.Column = 3;

            % Create ControlGrid  
            app.ControlGrid = uigridlayout(app.ControlPanel);
            app.ControlGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit'};
            app.ControlGrid.ColumnWidth = {'1x'};

            % Create StatusPanel
            app.StatusPanel = uipanel(app.MainGrid);
            app.StatusPanel.Layout.Row = 2;
            app.StatusPanel.Layout.Column = [1 3];

            % Create StatusGrid
            app.StatusGrid = uigridlayout(app.StatusPanel);
            app.StatusGrid.RowHeight = {'1x'};
            app.StatusGrid.ColumnWidth = {'1x'};

            % Create StatusLabel
            app.StatusLabel = uilabel(app.StatusGrid);
            app.StatusLabel.Layout.Row = 1;
            app.StatusLabel.Layout.Column = 1;
            app.StatusLabel.Text = 'Ready';
            app.StatusLabel.FontSize = 12;
            app.StatusLabel.FontWeight = 'bold';

            % Create control panels
            createDisplaySettings(app);
            createImageEnhancement(app);
            createAnnotationControls(app);
            createLabelManagement(app);
            createFileManagement(app);

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        function createDisplaySettings(app)
            % Create DisplayPanel
            app.DisplayPanel = uipanel(app.ControlGrid);
            app.DisplayPanel.Title = '1. Display Settings';
            app.DisplayPanel.Layout.Row = 1;
            app.DisplayPanel.Layout.Column = 1;

            % Create DisplayGrid
            app.DisplayGrid = uigridlayout(app.DisplayPanel);
            app.DisplayGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            app.DisplayGrid.ColumnWidth = {'1x', '1x'};

            % Create PlotInMmCheckBox
            app.PlotInMmCheckBox = uicheckbox(app.DisplayGrid);
            app.PlotInMmCheckBox.ValueChangedFcn = createCallbackFcn(app, @PlotInMmCheckBoxValueChanged, true);
            app.PlotInMmCheckBox.Text = 'Plot in mm';
            app.PlotInMmCheckBox.Layout.Row = 1;
            app.PlotInMmCheckBox.Layout.Column = [1 2];

            % Create FlipVerticalCheckBox
            app.FlipVerticalCheckBox = uicheckbox(app.DisplayGrid);
            app.FlipVerticalCheckBox.ValueChangedFcn = createCallbackFcn(app, @FlipVerticalCheckBoxValueChanged, true);
            app.FlipVerticalCheckBox.Text = 'Flip Vertical';
            app.FlipVerticalCheckBox.Value = true;
            app.FlipVerticalCheckBox.Layout.Row = 2;
            app.FlipVerticalCheckBox.Layout.Column = [1 2];

            % Create PixelSizeLabel
            app.PixelSizeLabel = uilabel(app.DisplayGrid);
            app.PixelSizeLabel.Text = 'Pixel Size (mm)';
            app.PixelSizeLabel.Layout.Row = 3;
            app.PixelSizeLabel.Layout.Column = 1;

            % Create PixelSizeEditField
            app.PixelSizeEditField = uieditfield(app.DisplayGrid, 'numeric');
            app.PixelSizeEditField.ValueChangedFcn = createCallbackFcn(app, @PixelSizeEditFieldValueChanged, true);
            app.PixelSizeEditField.Value = 0.1;
            app.PixelSizeEditField.Layout.Row = 3;
            app.PixelSizeEditField.Layout.Column = 2;

            % Create WaferSizeLabel
            app.WaferSizeLabel = uilabel(app.DisplayGrid);
            app.WaferSizeLabel.Text = 'Wafer Size (mm)';
            app.WaferSizeLabel.Layout.Row = 4;
            app.WaferSizeLabel.Layout.Column = 1;

            % Create WaferSizeEditField
            app.WaferSizeEditField = uieditfield(app.DisplayGrid, 'numeric');
            app.WaferSizeEditField.ValueChangedFcn = createCallbackFcn(app, @WaferSizeEditFieldValueChanged, true);
            app.WaferSizeEditField.Value = 150;
            app.WaferSizeEditField.Layout.Row = 4;
            app.WaferSizeEditField.Layout.Column = 2;
        end

        function createImageEnhancement(app)
            % Create EnhancementPanel
            app.EnhancementPanel = uipanel(app.ControlGrid);
            app.EnhancementPanel.Title = '2. Image Enhancement';
            app.EnhancementPanel.Layout.Row = 2;
            app.EnhancementPanel.Layout.Column = 1;

            % Create EnhancementGrid
            app.EnhancementGrid = uigridlayout(app.EnhancementPanel);
            app.EnhancementGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            app.EnhancementGrid.ColumnWidth = {'1x', '1x'};

            % Create LowClipLabel
            app.LowClipLabel = uilabel(app.EnhancementGrid);
            app.LowClipLabel.Text = 'Low Clip (0%)';
            app.LowClipLabel.Layout.Row = 1;
            app.LowClipLabel.Layout.Column = [1 2];

            % Create LowClipSlider
            app.LowClipSlider = uislider(app.EnhancementGrid);
            app.LowClipSlider.Limits = [0 50];
            app.LowClipSlider.ValueChangedFcn = createCallbackFcn(app, @LowClipSliderValueChanged, true);
            app.LowClipSlider.Layout.Row = 2;
            app.LowClipSlider.Layout.Column = [1 2];

            % Create LowClipValueLabel
            app.LowClipValueLabel = uilabel(app.EnhancementGrid);
            app.LowClipValueLabel.Text = '0.000';
            app.LowClipValueLabel.Layout.Row = 3;
            app.LowClipValueLabel.Layout.Column = [1 2];

            % Create HighClipLabel
            app.HighClipLabel = uilabel(app.EnhancementGrid);
            app.HighClipLabel.Text = 'High Clip (100%)';
            app.HighClipLabel.Layout.Row = 4;
            app.HighClipLabel.Layout.Column = [1 2];

            % Create HighClipSlider
            app.HighClipSlider = uislider(app.EnhancementGrid);
            app.HighClipSlider.Limits = [50 100];
            app.HighClipSlider.Value = 100;
            app.HighClipSlider.ValueChangedFcn = createCallbackFcn(app, @HighClipSliderValueChanged, true);
            app.HighClipSlider.Layout.Row = 5;
            app.HighClipSlider.Layout.Column = [1 2];

            % Create HighClipValueLabel
            app.HighClipValueLabel = uilabel(app.EnhancementGrid);
            app.HighClipValueLabel.Text = '1.000';
            app.HighClipValueLabel.Layout.Row = 6;
            app.HighClipValueLabel.Layout.Column = 1;

            % Create ResetClipButton
            app.ResetClipButton = uibutton(app.EnhancementGrid, 'push');
            app.ResetClipButton.ButtonPushedFcn = createCallbackFcn(app, @ResetClipButtonPushed, true);
            app.ResetClipButton.Layout.Row = 6;
            app.ResetClipButton.Layout.Column = 2;
            app.ResetClipButton.Text = 'Reset';
        end

        function createAnnotationControls(app)
            % Create AnnotationControlsPanel
            app.AnnotationControlsPanel = uipanel(app.ControlGrid);
            app.AnnotationControlsPanel.Title = '3. Annotation Controls';
            app.AnnotationControlsPanel.Layout.Row = 3;
            app.AnnotationControlsPanel.Layout.Column = 1;

            % Create AnnotationControlsGrid
            app.AnnotationControlsGrid = uigridlayout(app.AnnotationControlsPanel);
            app.AnnotationControlsGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            app.AnnotationControlsGrid.ColumnWidth = {'1x', '1x'};

            % Create BrushSizeLabel (Updated for initial size 1)
            app.BrushSizeLabel = uilabel(app.AnnotationControlsGrid);
            app.BrushSizeLabel.Text = 'Brush Size (1)';  % Update initial display to 1
            app.BrushSizeLabel.Layout.Row = 1;
            app.BrushSizeLabel.Layout.Column = [1 2];

            % Create BrushSizeSlider (Enhanced - Integer only steps)
            app.BrushSizeSlider = uislider(app.AnnotationControlsGrid);
            app.BrushSizeSlider.Limits = [1 10];
            app.BrushSizeSlider.Value = 1;  % Set initial value to 1
            app.BrushSizeSlider.MajorTicks = 1:10;  % Set major ticks to integers
            app.BrushSizeSlider.MajorTickLabels = {'1','2','3','4','5','6','7','8','9','10'};
            app.BrushSizeSlider.MinorTicks = [];  % Remove minor ticks to ensure sliding only on integers
            app.BrushSizeSlider.ValueChangedFcn = createCallbackFcn(app, @BrushSizeSliderValueChanged, true);
            app.BrushSizeSlider.Layout.Row = 2;
            app.BrushSizeSlider.Layout.Column = [1 2];

            % Create BrushModeButton
            app.BrushModeButton = uibutton(app.AnnotationControlsGrid, 'state');
            app.BrushModeButton.ValueChangedFcn = createCallbackFcn(app, @BrushModeButtonValueChanged, true);
            app.BrushModeButton.Text = 'Brush Mode';
            app.BrushModeButton.Layout.Row = 3;
            app.BrushModeButton.Layout.Column = [1 2];

            % Create PolygonModeButton
            app.PolygonModeButton = uibutton(app.AnnotationControlsGrid, 'state');
            app.PolygonModeButton.ValueChangedFcn = createCallbackFcn(app, @PolygonModeButtonValueChanged, true);
            app.PolygonModeButton.Text = 'Polygon Mode';
            app.PolygonModeButton.Layout.Row = 4;
            app.PolygonModeButton.Layout.Column = [1 2];

            % Create CancelPolygonButton
            app.CancelPolygonButton = uibutton(app.AnnotationControlsGrid, 'push');
            app.CancelPolygonButton.ButtonPushedFcn = createCallbackFcn(app, @CancelPolygonButtonPushed, true);
            app.CancelPolygonButton.Layout.Row = 5;
            app.CancelPolygonButton.Layout.Column = [1 2];
            app.CancelPolygonButton.Text = 'Cancel Polygon';
            app.CancelPolygonButton.BackgroundColor = [1 0.8 0.8];

            % Create ClearMaskButton
            app.ClearMaskButton = uibutton(app.AnnotationControlsGrid, 'push');
            app.ClearMaskButton.ButtonPushedFcn = createCallbackFcn(app, @ClearMaskButtonPushed, true);
            app.ClearMaskButton.Layout.Row = 6;
            app.ClearMaskButton.Layout.Column = 1;
            app.ClearMaskButton.Text = 'Clear Mask';
            
            % Create TestClickButton
            app.TestClickButton = uibutton(app.AnnotationControlsGrid, 'push');
            app.TestClickButton.ButtonPushedFcn = createCallbackFcn(app, @TestClickButtonPushed, true);
            app.TestClickButton.Layout.Row = 6;
            app.TestClickButton.Layout.Column = 2;
            app.TestClickButton.Text = 'Test Click';

            % Create UndoButton
            app.UndoButton = uibutton(app.AnnotationControlsGrid, 'push');
            app.UndoButton.ButtonPushedFcn = createCallbackFcn(app, @UndoButtonPushed, true);
            app.UndoButton.Layout.Row = 8;
            app.UndoButton.Layout.Column = 1;
            app.UndoButton.Text = 'Undo';

            % Create RedoButton
            app.RedoButton = uibutton(app.AnnotationControlsGrid, 'push');
            app.RedoButton.ButtonPushedFcn = createCallbackFcn(app, @RedoButtonPushed, true);
            app.RedoButton.Layout.Row = 8;
            app.RedoButton.Layout.Column = 2;
            app.RedoButton.Text = 'Redo';
        end

        function createLabelManagement(app)
            % Create LabelPanel
            app.LabelPanel = uipanel(app.ControlGrid);
            app.LabelPanel.Title = '4. Label Management';
            app.LabelPanel.Layout.Row = 4;
            app.LabelPanel.Layout.Column = 1;

            % Create LabelGrid
            app.LabelGrid = uigridlayout(app.LabelPanel);
            app.LabelGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            app.LabelGrid.ColumnWidth = {'1x', '1x'};

            % Create LabelListBox
            app.LabelListBox = uilistbox(app.LabelGrid);
            app.LabelListBox.Items = {'PL Star'};
            app.LabelListBox.Value = 'PL Star';
            app.LabelListBox.ValueChangedFcn = createCallbackFcn(app, @LabelListBoxValueChanged, true);
            app.LabelListBox.Layout.Row = 1;
            app.LabelListBox.Layout.Column = [1 2];

            % Create AddLabelButton
            app.AddLabelButton = uibutton(app.LabelGrid, 'push');
            app.AddLabelButton.ButtonPushedFcn = createCallbackFcn(app, @AddLabelButtonPushed, true);
            app.AddLabelButton.Layout.Row = 2;
            app.AddLabelButton.Layout.Column = 1;
            app.AddLabelButton.Text = 'Add Label';

            % Create DeleteLabelButton
            app.DeleteLabelButton = uibutton(app.LabelGrid, 'push');
            app.DeleteLabelButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteLabelButtonPushed, true);
            app.DeleteLabelButton.Layout.Row = 2;
            app.DeleteLabelButton.Layout.Column = 2;
            app.DeleteLabelButton.Text = 'Delete';

            % Create CurrentLabelDropDown
            app.CurrentLabelDropDown = uidropdown(app.LabelGrid);
            app.CurrentLabelDropDown.Items = {'PL Star'};
            app.CurrentLabelDropDown.Value = 'PL Star';
            app.CurrentLabelDropDown.ValueChangedFcn = createCallbackFcn(app, @CurrentLabelDropDownValueChanged, true);
            app.CurrentLabelDropDown.Layout.Row = 3;
            app.CurrentLabelDropDown.Layout.Column = [1 2];
        end

        function createFileManagement(app)
            % Create FilePanel
            app.FilePanel = uipanel(app.ControlGrid);
            app.FilePanel.Title = '5. File Management';
            app.FilePanel.Layout.Row = 5;
            app.FilePanel.Layout.Column = 1;

            % Create FileGrid
            app.FileGrid = uigridlayout(app.FilePanel);
            app.FileGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            app.FileGrid.ColumnWidth = {'1x', '1x'};

            % Create SelectFolderButton
            app.SelectFolderButton = uibutton(app.FileGrid, 'push');
            app.SelectFolderButton.ButtonPushedFcn = createCallbackFcn(app, @SelectFolderButtonPushed, true);
            app.SelectFolderButton.Layout.Row = 1;
            app.SelectFolderButton.Layout.Column = [1 2];
            app.SelectFolderButton.Text = 'Select Folder';

            % Create PreviousImageButton
            app.PreviousImageButton = uibutton(app.FileGrid, 'push');
            app.PreviousImageButton.ButtonPushedFcn = createCallbackFcn(app, @PreviousImageButtonPushed, true);
            app.PreviousImageButton.Layout.Row = 2;
            app.PreviousImageButton.Layout.Column = 1;
            app.PreviousImageButton.Text = 'Previous';

            % Create NextImageButton
            app.NextImageButton = uibutton(app.FileGrid, 'push');
            app.NextImageButton.ButtonPushedFcn = createCallbackFcn(app, @NextImageButtonPushed, true);
            app.NextImageButton.Layout.Row = 2;
            app.NextImageButton.Layout.Column = 2;
            app.NextImageButton.Text = 'Next';

            % Create CurrentFileLabel
            app.CurrentFileLabel = uilabel(app.FileGrid);
            app.CurrentFileLabel.Text = 'No file selected';
            app.CurrentFileLabel.Layout.Row = 3;
            app.CurrentFileLabel.Layout.Column = [1 2];

            % Create SaveAnnotationButton
            app.SaveAnnotationButton = uibutton(app.FileGrid, 'push');
            app.SaveAnnotationButton.ButtonPushedFcn = createCallbackFcn(app, @SaveAnnotationButtonPushed, true);
            app.SaveAnnotationButton.Layout.Row = 4;
            app.SaveAnnotationButton.Layout.Column = [1 2];
            app.SaveAnnotationButton.Text = 'Save Annotation';
        end
    end

    % Component initialization
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Initialize default values
            app.pixelSizeMm = 0.1;
            app.waferSizeMM = 150;
            app.flipVertical = true;
            app.bPlotInMm = false;
            app.brushSize = 1;  % Set initial brush size to 1
            app.currentLabel = 'PL Star';
            app.brushMode = false;
            app.polygonMode = false;
            
            % Initialize drawing state (from DragMaskGeneratorApp)
            app.IsDrawing = false;
            app.IsInteractiveMode = false;
            app.PolygonPoints = [];
            app.PolygonHandles = [];
            app.IsPolygonActive = false;
            app.PolygonCloseTolerance = 3;  % Reduce polygon close tolerance to 3 pixels for more precise control
            
            % Initialize label colors
            app.labelColors = containers.Map();
            app.labelColors('PL Star') = [1 0 0]; % Red color for PL Star
            
            % Initialize annotation data
            app.annotationData = containers.Map();
            app.combinedMask = [];
            
            % Initialize Cancel Polygon button state (Enhanced)
            app.CancelPolygonButton.Enable = 'off';
            app.CancelPolygonButton.BackgroundColor = [0.94 0.94 0.94]; % Default gray color
            app.CancelPolygonButton.Text = 'Cancel Polygon';
            
            % new
            app.annotationHistory = {};
            app.historyIndex = 0;
            
            % Update status
            app.StatusLabel.Text = 'Application initialized. Select a folder to begin.';
            
            fprintf('\n=== Enhanced Wafer Map Annotator (Brush Size 1 + Tighter Polygon Close) ===\n');
            fprintf('Improvements:\n');
            fprintf('1. Brush size starts at 1 (integer steps 1-10)\n');
            fprintf('2. Polygon close tolerance reduced to 5 pixels\n');
            fprintf('3. Fixed zoom state preservation during annotation\n');
            fprintf('4. Enhanced polygon controls with keyboard shortcuts\n');
            fprintf('5. Smart Cancel Polygon button with visual feedback\n');
        end
    end

    % Callbacks that handle component events (main callbacks)
    methods (Access = private)

        % Value changed function: PlotInMmCheckBox
        function PlotInMmCheckBoxValueChanged(app, event)
            app.bPlotInMm = app.PlotInMmCheckBox.Value;
            updateDisplay(app);
        end

        % Value changed function: FlipVerticalCheckBox
        function FlipVerticalCheckBoxValueChanged(app, event)
            app.flipVertical = app.FlipVerticalCheckBox.Value;
            if ~isempty(app.originalMap)
                processImageData(app);
                updateDisplay(app);
            end
        end

        % Value changed function: PixelSizeEditField
        function PixelSizeEditFieldValueChanged(app, event)
            app.pixelSizeMm = app.PixelSizeEditField.Value;
            updateDisplay(app);
        end

        % Value changed function: WaferSizeEditField
        function WaferSizeEditFieldValueChanged(app, event)
            app.waferSizeMM = app.WaferSizeEditField.Value;
            updateDisplay(app);
        end

        % Value changed function: LowClipSlider
        function LowClipSliderValueChanged(app, event)
            updateClipping(app);
        end

        % Value changed function: HighClipSlider
        function HighClipSliderValueChanged(app, event)
            updateClipping(app);
        end

        % Button pushed function: ResetClipButton
        function ResetClipButtonPushed(app, event)
            app.LowClipSlider.Value = 5;
            app.HighClipSlider.Value = 95;
            updateClipping(app);
        end

        % Value changed function: BrushSizeSlider (Enhanced - Integer values only)
        function BrushSizeSliderValueChanged(app, event)
            % Ensure value is integer
            sliderValue = round(app.BrushSizeSlider.Value);
            
            % If slider value is not integer, force set to integer
            if sliderValue ~= app.BrushSizeSlider.Value
                app.BrushSizeSlider.Value = sliderValue;
            end
            
            app.brushSize = sliderValue;
            app.BrushSizeLabel.Text = sprintf('Brush Size (%d)', app.brushSize);
            
            fprintf('Brush size changed to: %d\n', app.brushSize);
        end

        % Value changed function: BrushModeButton (Fixed version)
        function BrushModeButtonValueChanged(app, event)
            app.brushMode = app.BrushModeButton.Value;
            if app.brushMode
                % Disable polygon mode when brush mode is enabled
                app.polygonMode = false;
                app.PolygonModeButton.Value = false;
                app.cancelCurrentPolygon(); % Clear any active polygon
                
                % Set up mouse callbacks using UIFigure (DragMaskGeneratorApp approach)
                try
                    app.UIFigure.WindowButtonDownFcn = @(~,~) app.startDrawing();
                    app.UIFigure.WindowButtonMotionFcn = @(~,~) app.continueDrawing();
                    app.UIFigure.WindowButtonUpFcn = @(~,~) app.stopDrawing();
                    
                    % Also set up backup UIAxes callback
                    app.HazemapUIAxes.ButtonDownFcn = @(~,~) app.singleClickDraw();
                    
                    app.StatusLabel.Text = 'Brush mode ACTIVE - Click and drag on hazemap to annotate';
                    fprintf('Brush mode enabled\n');
                    
                catch ME
                    app.StatusLabel.Text = sprintf('Error setting up brush mode: %s', ME.message);
                end
            else
                % Disable brush mode
                app.StatusLabel.Text = 'Brush mode disabled';
                app.clearMouseCallbacks();
                fprintf('Brush mode disabled\n');
            end
        end

        % Value changed function: PolygonModeButton (Enhanced version)
        function PolygonModeButtonValueChanged(app, event)
            app.polygonMode = app.PolygonModeButton.Value;
            if app.polygonMode
                % Disable brush mode when polygon mode is enabled
                app.brushMode = false;
                app.BrushModeButton.Value = false;
                
                % Initialize polygon drawing
                app.PolygonPoints = [];
                app.IsPolygonActive = false;
                app.clearPolygonVisualization();
                
                % Enable Cancel button and change color for better visibility
                app.CancelPolygonButton.Enable = 'on';
                app.CancelPolygonButton.BackgroundColor = [1 0.9 0.6]; % More visible yellow color
                app.CancelPolygonButton.Text = 'Cancel Polygon (ESC)';
                
                % Set up mouse callbacks for polygon mode
                try
                    app.clearMouseCallbacks();
                    app.UIFigure.WindowButtonDownFcn = @(~,~) app.startPolygonDrawing();
                    
                    % Add keyboard callback to support ESC key
                    app.UIFigure.WindowKeyPressFcn = @(~,evt) app.handleKeyPress(evt);
                    
                    app.StatusLabel.Text = 'Polygon mode ACTIVE - Click on hazemap to add points, click near first point or press Enter to close, ESC to cancel';
                    fprintf('Polygon mode enabled\n');
                    
                catch ME
                    app.StatusLabel.Text = sprintf('Error setting up polygon mode: %s', ME.message);
                end
            else
                % Disable polygon mode
                app.StatusLabel.Text = 'Polygon mode disabled';
                app.cancelCurrentPolygon();
                app.clearMouseCallbacks();
                app.UIFigure.WindowKeyPressFcn = []; % Clear keyboard callback
                
                % Disable Cancel button and restore original color
                app.CancelPolygonButton.Enable = 'off';
                app.CancelPolygonButton.BackgroundColor = [0.94 0.94 0.94]; % Default gray color
                app.CancelPolygonButton.Text = 'Cancel Polygon';
                
                fprintf('Polygon mode disabled\n');
            end
        end

        % Button pushed function: CancelPolygonButton (Enhanced version)
        function CancelPolygonButtonPushed(app, event)
            if app.polygonMode
                % Record cancelled point count for feedback
                pointCount = 0;
                if ~isempty(app.PolygonPoints)
                    pointCount = size(app.PolygonPoints, 1);
                end
                
                app.cancelCurrentPolygon();
                
                % Better user feedback
                if pointCount > 0
                    app.StatusLabel.Text = sprintf('Polygon with %d points cancelled - ready for new polygon', pointCount);
                else
                    app.StatusLabel.Text = 'Ready to start new polygon';
                end
                
                fprintf('Polygon cancelled (had %d points)\n', pointCount);
                
                % Temporary button flash for visual feedback
                originalColor = app.CancelPolygonButton.BackgroundColor;
                app.CancelPolygonButton.BackgroundColor = [0.8 1 0.8]; % Green color
                drawnow; % Force immediate display update
                pause(0.2);
                app.CancelPolygonButton.BackgroundColor = originalColor;
            else
                app.StatusLabel.Text = 'Cancel polygon is only available in polygon mode';
            end
        end

        % Button pushed function: ClearMaskButton
        function ClearMaskButtonPushed(app, event)
            if ~isempty(app.annotationData)
                % Clear all annotation data
                labelKeys = app.annotationData.keys;
                for i = 1:length(labelKeys)
                    app.annotationData(labelKeys{i}) = false(size(app.workingMap));
                end
                app.combinedMask = false(size(app.workingMap));
                
                % Save to history
                saveToHistory(app);
                
                % Update both displays
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                
                app.StatusLabel.Text = 'All annotations cleared';
            end
        end

        % Button pushed function: TestClickButton (Enhanced)
        function TestClickButtonPushed(app, event)
            if isempty(app.workingMap)
                app.StatusLabel.Text = 'Please load an image first to test click functionality';
                return;
            end
            
            % Clear existing callbacks
            app.clearMouseCallbacks();
            
            % Set up test callback using same approach as DragMaskGeneratorApp
            app.UIFigure.WindowButtonDownFcn = @(~,~) app.testClickEvent();
            app.HazemapUIAxes.ButtonDownFcn = @(~,~) app.testClickAxes();
            
            app.StatusLabel.Text = 'TEST MODE: Click on the hazemap to test mouse events';
        end

        % Button pushed function: UndoButton
        function UndoButtonPushed(app, event)
            if app.historyIndex > 1
                app.historyIndex = app.historyIndex - 1;
                
                % Deep copy history status
                historicalState = app.annotationHistory{app.historyIndex};
                app.annotationData = containers.Map();
                if ~isempty(historicalState)
                    keys = historicalState.keys;
                    for i = 1:length(keys)
                        app.annotationData(keys{i}) = historicalState(keys{i});
                    end
                end
                
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                app.StatusLabel.Text = sprintf('Undo performed (step %d/%d)', app.historyIndex, length(app.annotationHistory));
            else
                app.StatusLabel.Text = 'Nothing to undo';
            end
        end
        
        % Button pushed function: RedoButton
        function RedoButtonPushed(app, event)
            if app.historyIndex < length(app.annotationHistory)
                app.historyIndex = app.historyIndex + 1;
                
                % Deep copy history status
                historicalState = app.annotationHistory{app.historyIndex};
                app.annotationData = containers.Map();
                if ~isempty(historicalState)
                    keys = historicalState.keys;
                    for i = 1:length(keys)
                        app.annotationData(keys{i}) = historicalState(keys{i});
                    end
                end
                
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                app.StatusLabel.Text = sprintf('Redo performed (step %d/%d)', app.historyIndex, length(app.annotationHistory));
            else
                app.StatusLabel.Text = 'Nothing to redo';
            end
        end
        % Label management callbacks
        function LabelListBoxValueChanged(app, event)
            app.currentLabel = app.LabelListBox.Value;
            app.CurrentLabelDropDown.Value = app.currentLabel;
        end

        function AddLabelButtonPushed(app, event)
            answer = inputdlg('Enter label name:', 'Add Label', 1, {sprintf('Label%d', length(app.LabelListBox.Items)+1)});
            if ~isempty(answer) && ~isempty(answer{1})
                newLabel = answer{1};
                if ~ismember(newLabel, app.LabelListBox.Items)
                    app.LabelListBox.Items{end+1} = newLabel;
                    app.CurrentLabelDropDown.Items{end+1} = newLabel;
                    
                    % Assign random color
                    app.labelColors(newLabel) = rand(1,3);
                    
                    % Initialize empty mask for new label
                    if ~isempty(app.workingMap)
                        app.annotationData(newLabel) = false(size(app.workingMap));
                    end
                    
                    app.StatusLabel.Text = sprintf('Label "%s" added', newLabel);
                else
                    app.StatusLabel.Text = 'Label already exists';
                end
            end
        end

        function DeleteLabelButtonPushed(app, event)
            selectedLabel = app.LabelListBox.Value;
            if ~isempty(selectedLabel) && length(app.LabelListBox.Items) > 1
                % Remove from lists
                app.LabelListBox.Items(strcmp(app.LabelListBox.Items, selectedLabel)) = [];
                app.CurrentLabelDropDown.Items(strcmp(app.CurrentLabelDropDown.Items, selectedLabel)) = [];
                
                % Remove from color map and annotation data
                if app.labelColors.isKey(selectedLabel)
                    app.labelColors.remove(selectedLabel);
                end
                if app.annotationData.isKey(selectedLabel)
                    app.annotationData.remove(selectedLabel);
                end
                
                % Update current selection
                if ~isempty(app.LabelListBox.Items)
                    app.LabelListBox.Value = app.LabelListBox.Items{1};
                    app.CurrentLabelDropDown.Value = app.LabelListBox.Items{1};
                    app.currentLabel = app.LabelListBox.Items{1};
                end
                
                app.StatusLabel.Text = sprintf('Label "%s" deleted', selectedLabel);
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
            elseif length(app.LabelListBox.Items) <= 1
                app.StatusLabel.Text = 'Cannot delete the last label';
            end
        end

        function CurrentLabelDropDownValueChanged(app, event)
            app.currentLabel = app.CurrentLabelDropDown.Value;
            app.LabelListBox.Value = app.currentLabel;
        end

        % File management callbacks
        function SelectFolderButtonPushed(app, event)
            folder = uigetdir('', 'Select folder containing .mat files');
            if folder ~= 0
                app.selectedFolder = folder;
                
                % Find all .mat files in the folder
                files = dir(fullfile(folder, '*.mat'));
                if ~isempty(files)
                    app.imageFiles = {files.name};
                    app.currentImageIndex = 1;
                    loadCurrentImage(app);
                    app.StatusLabel.Text = sprintf('Loaded folder with %d files', length(app.imageFiles));
                else
                    app.StatusLabel.Text = 'No .mat files found in selected folder';
                end
            end
        end

        function PreviousImageButtonPushed(app, event)
            if app.currentImageIndex > 1
                app.currentImageIndex = app.currentImageIndex - 1;
                loadCurrentImage(app);
            end
        end

        function NextImageButtonPushed(app, event)
            if app.currentImageIndex < length(app.imageFiles)
                app.currentImageIndex = app.currentImageIndex + 1;
                loadCurrentImage(app);
            end
        end

        function SaveAnnotationButtonPushed(app, event)
            if ~isempty(app.annotationData) && ~isempty(app.imageFiles)
                currentFile = app.imageFiles{app.currentImageIndex};
                [~, name, ~] = fileparts(currentFile);
                
                % Save annotation data
                annotationMask = app.annotationData;
                saveFile = fullfile(app.selectedFolder, [name '_annotation.mat']);
                save(saveFile, 'annotationMask');
                
                app.StatusLabel.Text = sprintf('Annotation saved to %s', saveFile);
            else
                app.StatusLabel.Text = 'No annotation data to save';
            end
        end
    end

    % Drawing methods (optimized versions)
    methods (Access = private)
        
        function startDrawing(app)
            % Mouse button down for brush drawing (optimized version)
            if ~app.brushMode || ~app.isMouseInImageArea()
                return;
            end
            
            app.IsDrawing = true;
            fprintf('\n*** Starting brush drawing ***\n');
            app.drawAtCurrentMousePosition();
            app.StatusLabel.Text = sprintf('Drawing with brush on %s...', app.currentLabel);
        end
        
        function continueDrawing(app)
            % Mouse motion during brush drawing (optimized version)
            if app.brushMode && app.IsDrawing && app.isMouseInImageArea()
                app.drawAtCurrentMousePosition();
                fprintf('.');
            end
        end
        
        function stopDrawing(app)
            % Mouse button up for brush drawing (optimized version)
            if app.brushMode && app.IsDrawing
                app.IsDrawing = false;
                fprintf('\n*** Brush drawing completed ***\n');
                app.StatusLabel.Text = sprintf('Brush stroke completed on %s', app.currentLabel);
                
                % Clean up temporary brush overlays
                tempBrushes = findobj(app.HazemapUIAxes, 'Tag', 'TempBrush');
                delete(tempBrushes);
                
                % Now perform complete display update
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                
                % Save to history
                saveToHistory(app);
            end
        end
        
        function singleClickDraw(app)
            % Single click drawing (backup method)
            if app.brushMode && app.isMouseInImageArea()
                fprintf('\n*** Single click draw ***\n');
                app.drawAtCurrentMousePosition();
                app.StatusLabel.Text = sprintf('Single click annotation on %s', app.currentLabel);
                
                % Save to history
                saveToHistory(app);
            end
        end
        
        function startPolygonDrawing(app)
            % Start polygon point addition
            if ~app.polygonMode || ~app.isMouseInImageArea()
                return;
            end
            
            pos = app.HazemapUIAxes.CurrentPoint;
            x = pos(1,1);
            y = pos(1,2);
            
            app.addPolygonPoint(x, y);
        end
        
        function addPolygonPoint(app, x, y)
            % Add polygon point (Enhanced version with better feedback)
            try
                if isempty(app.PolygonPoints)
                    % First point
                    app.PolygonPoints = [x, y];
                    app.IsPolygonActive = true;
                    
                    % Update Cancel button state to indicate active polygon drawing
                    app.CancelPolygonButton.BackgroundColor = [1 0.7 0.7]; % Redder color for active state
                    app.CancelPolygonButton.Text = sprintf('Cancel Polygon (%d pts)', 1);
                    
                    fprintf('Adding polygon starting point: (%.1f, %.1f)\n', x, y);
                    app.StatusLabel.Text = sprintf('Polygon started at (%.1f, %.1f) - continue clicking, Enter to close, ESC to cancel', x, y);
                else
                    % Check if clicking near starting point (close polygon)
                    startPoint = app.PolygonPoints(1, :);
                    distance = sqrt((x - startPoint(1))^2 + (y - startPoint(2))^2);
                    
                    if distance <= app.PolygonCloseTolerance && size(app.PolygonPoints, 1) >= 3
                        % Close polygon
                        fprintf('Polygon closed! Generating mask...\n');
                        app.generatePolygonMask();
                        app.StatusLabel.Text = sprintf('Polygon completed and added to %s', app.currentLabel);
                        return;
                    end
                    
                    % Add new point
                    app.PolygonPoints = [app.PolygonPoints; x, y];
                    pointCount = size(app.PolygonPoints, 1);
                    
                    % Update Cancel button to show current point count
                    app.CancelPolygonButton.Text = sprintf('Cancel Polygon (%d pts)', pointCount);
                    
                    fprintf('Adding polygon point %d: (%.1f, %.1f)\n', pointCount, x, y);
                    app.StatusLabel.Text = sprintf('Added %d points - click near start point or press Enter to close, ESC to cancel', pointCount);
                end
                
                % Update visualization
                app.updatePolygonVisualization();
                
            catch ME
                fprintf('Error adding polygon point: %s\n', ME.message);
                app.StatusLabel.Text = sprintf('Error adding polygon point: %s', ME.message);
            end
        end
        
        function generatePolygonMask(app)
            % Generate polygon mask (Enhanced version with better feedback)
            try
                if size(app.PolygonPoints, 1) < 3
                    fprintf('Not enough polygon points to generate mask\n');
                    return;
                end
                
                % Get image dimensions
                [h, w] = size(app.workingMap);
                
                % Convert coordinates to pixel indices (Fixed coordinate conversion)
                if app.bPlotInMm
                    % Convert mm coordinates to pixel coordinates
                    centerPixel = w / 2;
                    xPixels = app.PolygonPoints(:,1) / app.pixelSizeMm + centerPixel + 0.5;
                    yPixels = app.PolygonPoints(:,2) / app.pixelSizeMm + centerPixel + 0.5;
                else
                    xPixels = app.PolygonPoints(:,1);
                    yPixels = app.PolygonPoints(:,2);
                end
                
                % Ensure coordinates are within bounds
                xPixels = max(1, min(w, xPixels));
                yPixels = max(1, min(h, yPixels));
                
                % Generate polygon mask using poly2mask
                polygonMask = poly2mask(xPixels, yPixels, h, w);
                
                % Add to current label's annotation data
                if app.annotationData.isKey(app.currentLabel)
                    app.annotationData(app.currentLabel) = app.annotationData(app.currentLabel) | polygonMask;
                else
                    app.annotationData(app.currentLabel) = polygonMask;
                end
                
                % Show success feedback after polygon completion
                if app.polygonMode
                    app.CancelPolygonButton.BackgroundColor = [0.8 1 0.8]; % Success green color
                    app.CancelPolygonButton.Text = 'Polygon Complete!';
                    drawnow; % Force immediate display update
                end
                
                % Update displays
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                
                % Brief display then restore to waiting state
                if app.polygonMode
                    pause(0.3);
                    app.CancelPolygonButton.BackgroundColor = [1 0.9 0.6]; % Back to waiting state
                    app.CancelPolygonButton.Text = 'Cancel Polygon (ESC)';
                end
                
                % Clean up polygon
                app.cancelCurrentPolygon();
                
                % Save to history
                saveToHistory(app);
                
                fprintf('Polygon mask generated with %d pixels\n', sum(polygonMask(:)));
                
            catch ME
                fprintf('Error generating polygon mask: %s\n', ME.message);
                app.StatusLabel.Text = sprintf('Error generating polygon mask: %s', ME.message);
            end
        end
        
        function updatePolygonVisualization(app)
            % Update polygon visualization
            try
                % Clear previous visualization
                app.clearPolygonVisualization();
                
                if isempty(app.PolygonPoints)
                    return;
                end
                
                hold(app.HazemapUIAxes, 'on');
                
                % Draw points
                app.PolygonHandles.points = plot(app.HazemapUIAxes, ...
                    app.PolygonPoints(:, 1), app.PolygonPoints(:, 2), ...
                    'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'red');
                
                % Highlight starting point
                if size(app.PolygonPoints, 1) >= 1
                    app.PolygonHandles.startPoint = plot(app.HazemapUIAxes, ...
                        app.PolygonPoints(1, 1), app.PolygonPoints(1, 2), ...
                        'go', 'MarkerSize', 12, 'MarkerFaceColor', 'green', 'LineWidth', 2);
                end
                
                % Draw lines connecting points
                if size(app.PolygonPoints, 1) >= 2
                    app.PolygonHandles.lines = plot(app.HazemapUIAxes, ...
                        app.PolygonPoints(:, 1), app.PolygonPoints(:, 2), ...
                        'b-', 'LineWidth', 2);
                end
                
                % Preview closing line if 3+ points
                if size(app.PolygonPoints, 1) >= 3
                    x_preview = [app.PolygonPoints(end, 1), app.PolygonPoints(1, 1)];
                    y_preview = [app.PolygonPoints(end, 2), app.PolygonPoints(1, 2)];
                    app.PolygonHandles.previewLine = plot(app.HazemapUIAxes, ...
                        x_preview, y_preview, 'g--', 'LineWidth', 1);
                end
                
                hold(app.HazemapUIAxes, 'off');
                
            catch ME
                fprintf('Error updating polygon visualization: %s\n', ME.message);
            end
        end
        
        function clearPolygonVisualization(app)
            % Clear polygon visualization
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
                fprintf('Error clearing polygon visualization: %s\n', ME.message);
            end
        end
        
        function cancelCurrentPolygon(app)
            % Cancel current polygon (Enhanced version)
            % Save cancelled point count for feedback
            cancelledPoints = 0;
            if ~isempty(app.PolygonPoints)
                cancelledPoints = size(app.PolygonPoints, 1);
            end
            
            % Cancel current polygon
            app.PolygonPoints = [];
            app.IsPolygonActive = false;
            app.clearPolygonVisualization();
            
            % Restore Cancel button state
            if app.polygonMode
                app.CancelPolygonButton.BackgroundColor = [1 0.9 0.6]; % Back to waiting state yellow
                app.CancelPolygonButton.Text = 'Cancel Polygon (ESC)';
            end
            
            fprintf('Cancelled polygon with %d points\n', cancelledPoints);
        end
        
        function clearMouseCallbacks(app)
            % Clear all mouse callbacks
            app.UIFigure.WindowButtonDownFcn = [];
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            app.HazemapUIAxes.ButtonDownFcn = [];
        end
        
        function handleKeyPress(app, eventData)
            % Handle keyboard events (New function for enhanced polygon control)
            switch eventData.Key
                case 'escape'
                    if app.polygonMode && app.IsPolygonActive
                        pointCount = 0;
                        if ~isempty(app.PolygonPoints)
                            pointCount = size(app.PolygonPoints, 1);
                        end
                        app.cancelCurrentPolygon();
                        app.StatusLabel.Text = sprintf('Polygon with %d points cancelled with ESC key', pointCount);
                        fprintf('Polygon cancelled with ESC (had %d points)\n', pointCount);
                    end
                case 'return' % Enter key
                    if app.polygonMode && size(app.PolygonPoints, 1) >= 3
                        % Force close polygon
                        app.generatePolygonMask();
                        app.StatusLabel.Text = 'Polygon forced to close with Enter key';
                        fprintf('Polygon forced closed with Enter\n');
                    elseif app.polygonMode && ~isempty(app.PolygonPoints)
                        app.StatusLabel.Text = sprintf('Need at least 3 points to close polygon (currently have %d)', size(app.PolygonPoints, 1));
                    end
            end
        end
        
        function inArea = isMouseInImageArea(app)
            % Check if mouse is in hazemap area (修复版本)
            try
                pos = app.HazemapUIAxes.CurrentPoint;
                x = pos(1,1);
                y = pos(1,2);
                
                if app.bPlotInMm
                    % For mm coordinates, check reasonable bounds
                    maxCoord = app.waferSizeMM / 2;
                    inArea = (x >= -maxCoord && x <= maxCoord && y >= -maxCoord && y <= maxCoord);
                else
                    % For pixel coordinates (Fixed boundary check)
                    [h, w] = size(app.workingMap);
                    inArea = (x >= 1 && x <= w && y >= 1 && y <= h);
                end
            catch
                inArea = false;
            end
        end
        
        function drawAtCurrentMousePosition(app)
            % Draw at current mouse position
            try
                pos = app.HazemapUIAxes.CurrentPoint;
                x = pos(1,1);
                y = pos(1,2);
                app.drawAtPosition(x, y);
            catch ME
                fprintf('Drawing error: %s\n', ME.message);
            end
        end
        
        function drawAtPosition(app, x, y)
            % Draw at specific position (Fixed version - Coordinate conversion consistency)
            if isempty(app.workingMap)
                return;
            end
            
            [h, w] = size(app.workingMap);
            
            % Convert coordinates to pixel indices (修复坐标转换)
            if app.bPlotInMm
                centerPixel = w / 2;
                xPixel = round(x / app.pixelSizeMm + centerPixel + 0.5);
                yPixel = round(y / app.pixelSizeMm + centerPixel + 0.5);
            else
                xPixel = round(x);
                yPixel = round(y);
            end
            
            % Check bounds
            if xPixel >= 1 && xPixel <= w && yPixel >= 1 && yPixel <= h
                % Create circular brush
                [meshX, meshY] = meshgrid(1:w, 1:h);
                distances = sqrt((meshX - xPixel).^2 + (meshY - yPixel).^2);
                brushMask = distances <= app.brushSize/2;
                
                % Update mask for current label
                if app.annotationData.isKey(app.currentLabel)
                    app.annotationData(app.currentLabel) = app.annotationData(app.currentLabel) | brushMask;
                else
                    app.annotationData(app.currentLabel) = brushMask;
                end
                
                % **Key optimization: Only update overlay during drawing, not full redraw**
                if app.IsDrawing
                    % During drawing: Add fast overlay points, no full redraw
                    app.addBrushOverlayFast(x, y);
                else
                    % After drawing completion: Full display update
                    updateHazemapDisplay(app);
                    updateAnnotationDisplay(app);
                end
                
                fprintf('Drew at position (%.1f, %.1f) with %d pixels\n', x, y, sum(brushMask(:)));
            else
                fprintf('Position (%.1f, %.1f) outside image bounds\n', x, y);
            end
        end
        
        % 新增辅助函数：快速添加brush overlay
        function addBrushOverlayFast(app, x, y)
            % Add visual feedback at current mouse position quickly, without redrawing entire image
            try
                hold(app.HazemapUIAxes, 'on');
                
                % Get current label color
                if app.labelColors.isKey(app.currentLabel)
                    color = app.labelColors(app.currentLabel);
                else
                    color = [1 0 0]; % Default red color
                end
                
                % Draw brush cursor
                theta = linspace(0, 2*pi, 20);
                brushRadius = app.brushSize / 2;
                brushX = x + brushRadius * cos(theta);
                brushY = y + brushRadius * sin(theta);
                
                % Temporarily show brush outline
                plot(app.HazemapUIAxes, brushX, brushY, 'Color', color, 'LineWidth', 2, 'Tag', 'TempBrush');
                
                hold(app.HazemapUIAxes, 'off');
                
            catch ME
                fprintf('Error in fast overlay: %s\n', ME.message);
            end
        end
        
        function testClickEvent(app)
            % Test UIFigure click event
            try
                if app.isMouseInImageArea()
                    pos = app.HazemapUIAxes.CurrentPoint;
                    app.StatusLabel.Text = sprintf('✅ UIFigure click detected at (%.1f, %.1f)', pos(1,1), pos(1,2));
                    fprintf('UIFigure click test successful at (%.1f, %.1f)\n', pos(1,1), pos(1,2));
                else
                    app.StatusLabel.Text = '⚠️ Click detected but outside image area';
                end
                
                % Clear test callbacks after 2 seconds
                pause(2);
                app.clearMouseCallbacks();
                app.StatusLabel.Text = 'Mouse test completed - ready for annotation';
            catch ME
                app.StatusLabel.Text = sprintf('❌ Error in UIFigure click test: %s', ME.message);
            end
        end
        
        function testClickAxes(app)
            % Test UIAxes click event
            try
                pos = app.HazemapUIAxes.CurrentPoint;
                app.StatusLabel.Text = sprintf('✅ UIAxes click detected at (%.1f, %.1f)', pos(1,1), pos(1,2));
                fprintf('UIAxes click test successful at (%.1f, %.1f)\n', pos(1,1), pos(1,2));
                
                % Clear test callbacks after 2 seconds
                pause(2);
                app.clearMouseCallbacks();
                app.StatusLabel.Text = 'Mouse test completed - ready for annotation';
            catch ME
                app.StatusLabel.Text = sprintf('❌ Error in UIAxes click test: %s', ME.message);
            end
        end
    end

    % Helper methods (优化版本)
    methods (Access = private)
        
        function loadCurrentImage(app)
            if ~isempty(app.imageFiles) && app.currentImageIndex <= length(app.imageFiles)
                currentFile = app.imageFiles{app.currentImageIndex};
                filePath = fullfile(app.selectedFolder, currentFile);
                
                try
                    data = load(filePath);
                    if isfield(data, 'dw_image')
                        app.originalMap = data.dw_image;
                        processImageData(app);
                        setupImageDisplay(app);
                        updateDisplay(app);
                        app.CurrentFileLabel.Text = currentFile;
                        
                        % Reset annotation data for new image
                        app.annotationData = containers.Map();
                        keys = app.labelColors.keys;
                        for i = 1:length(keys)
                            app.annotationData(keys{i}) = false(size(app.originalMap));
                        end
                        
                        % new
                        app.annotationHistory = {};
                        app.historyIndex = 0;
                        saveToHistory(app);
                        
                        % Initialize combined mask
                        app.combinedMask = false(size(app.originalMap));
                        
                        % Reset annotation modes and clear callbacks
                        app.brushMode = false;
                        app.polygonMode = false;
                        app.BrushModeButton.Value = false;
                        app.PolygonModeButton.Value = false;
                        app.cancelCurrentPolygon();
                        app.clearMouseCallbacks();
                        
                        app.StatusLabel.Text = sprintf('Loaded image %d of %d: %s', ...
                            app.currentImageIndex, length(app.imageFiles), currentFile);
                    else
                        app.StatusLabel.Text = 'File does not contain dw_image field';
                    end
                catch ME
                    app.StatusLabel.Text = sprintf('Error loading file: %s', ME.message);
                end
            end
        end
        
        function setupImageDisplay(app)
            % Set up image display with proper mouse interaction
            if ~isempty(app.workingMap)
                fprintf('Setting up image display...\n');
                
                % Set axes properties for interaction
                app.HazemapUIAxes.XTick = [];
                app.HazemapUIAxes.YTick = [];
                app.HazemapUIAxes.Box = 'on';
                
                fprintf('Image display setup complete\n');
            end
        end
        
        function processImageData(app)
            if ~isempty(app.originalMap)
                % Apply vertical flip if needed
                if app.flipVertical
                    app.workingMap = flipud(app.originalMap);
                else
                    app.workingMap = app.originalMap;
                end
                
                % Prepare data for percentile calculations
                app.workingMap(app.workingMap == 0 | app.workingMap == min(app.workingMap(:))) = NaN;
                app.validData = app.workingMap(~isnan(app.workingMap));
                
                % Reset clipping
                updateClipping(app);
            end
        end
        
        function updateClipping(app)
            if isempty(app.validData)
                return;
            end
            
            % Get slider values
            lowClipPercent = app.LowClipSlider.Value;
            highClipPercent = app.HighClipSlider.Value;
            
            % Ensure proper ordering
            if lowClipPercent >= highClipPercent - 1
                if lowClipPercent >= 49
                    app.LowClipSlider.Value = highClipPercent - 1;
                    lowClipPercent = highClipPercent - 1;
                else
                    app.HighClipSlider.Value = lowClipPercent + 1;
                    highClipPercent = lowClipPercent + 1;
                end
            end
            
            % Calculate clip values
            lowClip = prctile(app.validData, lowClipPercent);
            highClip = prctile(app.validData, highClipPercent);
            
            % Update labels
            app.LowClipLabel.Text = sprintf('Low Clip (%.1f%%)', lowClipPercent);
            app.HighClipLabel.Text = sprintf('High Clip (%.1f%%)', highClipPercent);
            app.LowClipValueLabel.Text = sprintf('%.3f', lowClip);
            app.HighClipValueLabel.Text = sprintf('%.3f', highClip);
            
            % Update hazemap display only
            if ~isempty(app.hazemapImageHandle) && isvalid(app.hazemapImageHandle)
                app.hazemapImageHandle.CData = app.workingMap;
                clim(app.HazemapUIAxes, [lowClip, highClip]);
            end
        end
        
        function updateDisplay(app)
            if isempty(app.workingMap)
                return;
            end
            
            % Update both hazemap and annotation displays
            updateHazemapDisplay(app);
            updateAnnotationDisplay(app);
        end
        
        function updateHazemapDisplay(app)
            % repair for zoom status label
            if isempty(app.workingMap)
                return;
            end
            
            % Calculate coordinates (Fixed coordinate calculation)
            [h, w] = size(app.workingMap);
            
            if app.bPlotInMm
                % Fixed coordinate calculation formula
                centerPixel = w / 2;
                xCoord = ((1:w) - centerPixel - 0.5) * app.pixelSizeMm;
                yCoord = ((1:h) - centerPixel - 0.5) * app.pixelSizeMm;
                xLabelText = 'X (mm)';
                yLabelText = 'Y (mm)';
            else
                xCoord = 1:w;
                yCoord = 1:h;
                xLabelText = 'X (pixels)';
                yLabelText = 'Y (pixels)';
            end
            
            % Store current callbacks before clearing
            currentWindowDown = app.UIFigure.WindowButtonDownFcn;
            currentWindowMotion = app.UIFigure.WindowButtonMotionFcn;
            currentWindowUp = app.UIFigure.WindowButtonUpFcn;
            currentAxesDown = app.HazemapUIAxes.ButtonDownFcn;
            
            % **Fix: Save zoom state but intelligently determine whether to restore**
            currentXLim = [];
            currentYLim = [];
            shouldRestoreZoom = false;
            
            % Only save if not first display and has valid zoom state
            if ~isempty(app.hazemapImageHandle) && isvalid(app.hazemapImageHandle)
                try
                    currentXLim = app.HazemapUIAxes.XLim;
                    currentYLim = app.HazemapUIAxes.YLim;
                    
                    % Check if really zoomed (not default tight state)
                    if all(isfinite([currentXLim, currentYLim])) && ...
                       currentXLim(1) ~= currentXLim(2) && currentYLim(1) ~= currentYLim(2)
                        % Further check: Is zoom range smaller than image range (really zoomed)
                        if app.bPlotInMm
                            imageXRange = [min(xCoord), max(xCoord)];
                            imageYRange = [min(yCoord), max(yCoord)];
                        else
                            imageXRange = [1, w];
                            imageYRange = [1, h];
                        end
                        
                        % If current display range is smaller than image range, it means zoomed
                        if (currentXLim(2) - currentXLim(1)) < 0.9 * (imageXRange(2) - imageXRange(1)) || ...
                           (currentYLim(2) - currentYLim(1)) < 0.9 * (imageYRange(2) - imageYRange(1))
                            shouldRestoreZoom = true;
                        end
                    end
                catch
                    % If getting current state fails, don't restore zoom
                    shouldRestoreZoom = false;
                end
            end
            
            % Check if full redraw is needed
            if isempty(app.hazemapImageHandle) || ~isvalid(app.hazemapImageHandle)
                % Complete reinitialization
                cla(app.HazemapUIAxes);
                needsFullRedraw = true;
            else
                % Only clear overlays, keep base image
                children = app.HazemapUIAxes.Children;
                % Delete all objects except base image
                for i = 1:length(children)
                    if children(i) ~= app.hazemapImageHandle
                        delete(children(i));
                    end
                end
                needsFullRedraw = false;
            end
            
            % Display base hazemap
            if needsFullRedraw
                app.hazemapImageHandle = imagesc(app.HazemapUIAxes, xCoord, yCoord, app.workingMap);
                colormap(app.HazemapUIAxes, 'jet');
                colorbar(app.HazemapUIAxes);
                axis(app.HazemapUIAxes, 'equal');
                axis(app.HazemapUIAxes, 'xy');
                app.HazemapUIAxes.XLabel.String = xLabelText;
                app.HazemapUIAxes.YLabel.String = yLabelText;
                
                % Set to tight first to ensure complete image display
                axis(app.HazemapUIAxes, 'tight');
            else
                % Only update existing image data
                app.hazemapImageHandle.CData = app.workingMap;
                % Update coordinates (may switch from pixels to mm or vice versa)
                app.hazemapImageHandle.XData = xCoord;
                app.hazemapImageHandle.YData = yCoord;
                app.HazemapUIAxes.XLabel.String = xLabelText;
                app.HazemapUIAxes.YLabel.String = yLabelText;
            end
            
            % Restore callbacks
            app.UIFigure.WindowButtonDownFcn = currentWindowDown;
            app.UIFigure.WindowButtonMotionFcn = currentWindowMotion;
            app.UIFigure.WindowButtonUpFcn = currentWindowUp;
            app.HazemapUIAxes.ButtonDownFcn = currentAxesDown;
            
            % Overlay colored annotation masks
            hold(app.HazemapUIAxes, 'on');
            if ~isempty(app.annotationData)
                labelKeys = app.annotationData.keys;
                for i = 1:length(labelKeys)
                    mask = app.annotationData(labelKeys{i});
                    if any(mask(:))
                        color = app.labelColors(labelKeys{i});
                        
                        % Create RGB overlay for this label
                        overlayRGB = cat(3, color(1)*double(mask), color(2)*double(mask), color(3)*double(mask));
                        
                        % Display colored overlay with transparency
                        h_overlay = imagesc(app.HazemapUIAxes, xCoord, yCoord, overlayRGB);
                        h_overlay.AlphaData = 0.5 * double(mask);
                        h_overlay.HitTest = 'off'; % Allow clicks to pass through
                    end
                end
            end
            hold(app.HazemapUIAxes, 'off');
            
            % **Fix: Only restore zoom state when actually needed**
            if shouldRestoreZoom && ~isempty(currentXLim) && ~isempty(currentYLim)
                app.HazemapUIAxes.XLim = currentXLim;
                app.HazemapUIAxes.YLim = currentYLim;
                fprintf('Zoom state restored\n');
            else
                fprintf('No zoom to restore or first time display\n');
            end
            
            title(app.HazemapUIAxes, 'Hazemap with Annotations');
            
            % Update title with file info
            if ~isempty(app.CurrentFileLabel) && ~strcmp(app.CurrentFileLabel.Text, 'No file selected')
                title(app.HazemapUIAxes, sprintf('Hazemap: %s', app.CurrentFileLabel.Text));
            end
            
            fprintf('Hazemap display updated\n');
        end
        
        function updateAnnotationDisplay(app)
            % 修复版本：保持zoom状态但确保初始显示正确
            if isempty(app.workingMap)
                return;
            end
            
            % Calculate coordinates (Fixed coordinate calculation)
            [h, w] = size(app.workingMap);
            
            if app.bPlotInMm
                % Fixed coordinate calculation formula
                centerPixel = w / 2;
                xCoord = ((1:w) - centerPixel - 0.5) * app.pixelSizeMm;
                yCoord = ((1:h) - centerPixel - 0.5) * app.pixelSizeMm;
                xLabelText = 'X (mm)';
                yLabelText = 'Y (mm)';
            else
                xCoord = 1:w;
                yCoord = 1:h;
                xLabelText = 'X (pixels)';
                yLabelText = 'Y (pixels)';
            end
            
            % **Intelligently save zoom state**
            currentXLim = [];
            currentYLim = [];
            shouldRestoreZoom = false;
            
            % Only save if not first display and has valid zoom state
            if ~isempty(app.annotationImageHandle) && isvalid(app.annotationImageHandle)
                try
                    currentXLim = app.AnnotationUIAxes.XLim;
                    currentYLim = app.AnnotationUIAxes.YLim;
                    
                    % Check if really zoomed
                    if all(isfinite([currentXLim, currentYLim])) && ...
                       currentXLim(1) ~= currentXLim(2) && currentYLim(1) ~= currentYLim(2)
                        % Further check: Is zoom range smaller than image range
                        if app.bPlotInMm
                            imageXRange = [min(xCoord), max(xCoord)];
                            imageYRange = [min(yCoord), max(yCoord)];
                        else
                            imageXRange = [1, w];
                            imageYRange = [1, h];
                        end
                        
                        % If current display range is smaller than image range, it means zoomed
                        if (currentXLim(2) - currentXLim(1)) < 0.9 * (imageXRange(2) - imageXRange(1)) || ...
                           (currentYLim(2) - currentYLim(1)) < 0.9 * (imageYRange(2) - imageYRange(1))
                            shouldRestoreZoom = true;
                        end
                    end
                catch
                    shouldRestoreZoom = false;
                end
            end
            
            % Update combined mask
            updateCombinedMask(app);
            
            % Create black and white mask display
            maskDisplay = double(app.combinedMask);
            
            % Update Annotation Display (Right Panel) - Black and White
            cla(app.AnnotationUIAxes);
            app.annotationImageHandle = imagesc(app.AnnotationUIAxes, xCoord, yCoord, maskDisplay);
            colormap(app.AnnotationUIAxes, [0 0 0; 1 1 1]); % Black and white colormap
            axis(app.AnnotationUIAxes, 'equal');
            axis(app.AnnotationUIAxes, 'xy');
            app.AnnotationUIAxes.XLabel.String = xLabelText;
            app.AnnotationUIAxes.YLabel.String = yLabelText;
            
            % Set to tight first to ensure complete image display
            axis(app.AnnotationUIAxes, 'tight');
            
            % **Fix: Only restore zoom state when actually needed**
            if shouldRestoreZoom && ~isempty(currentXLim) && ~isempty(currentYLim)
                app.AnnotationUIAxes.XLim = currentXLim;
                app.AnnotationUIAxes.YLim = currentYLim;
            end
            
            % Count annotated pixels
            annotatedPixels = sum(app.combinedMask(:));
            totalPixels = numel(app.combinedMask);
            percentage = (annotatedPixels / totalPixels) * 100;
            
            title(app.AnnotationUIAxes, sprintf('Annotation Mask (%.1f%% covered)', percentage));
            
            % Link axes for synchronized zoom/pan
            linkaxes([app.HazemapUIAxes, app.AnnotationUIAxes], 'xy');
            
            fprintf('Annotation display updated\n');
        end
        
        function updateCombinedMask(app)
            if isempty(app.annotationData) || isempty(app.workingMap)
                app.combinedMask = false(size(app.workingMap));
                return;
            end
            
            % Combine all label masks
            app.combinedMask = false(size(app.workingMap));
            labelKeys = app.annotationData.keys;
            for i = 1:length(labelKeys)
                if app.annotationData.isKey(labelKeys{i})
                    app.combinedMask = app.combinedMask | app.annotationData(labelKeys{i});
                end
            end
        end

        function saveToHistory(app)
            % Trim history if needed
            if app.historyIndex < length(app.annotationHistory)
                app.annotationHistory = app.annotationHistory(1:app.historyIndex);
            end
            
            % deep copy current annotation
            currentStateCopy = containers.Map();
            if ~isempty(app.annotationData)
                keys = app.annotationData.keys;
                for i = 1:length(keys)
                    % copy each mask's label
                    currentStateCopy(keys{i}) = app.annotationData(keys{i});
                end
            end
            
            % Add current state copy to history
            app.annotationHistory{end+1} = currentStateCopy;
            app.historyIndex = length(app.annotationHistory);
            
            % Limit history size
            if length(app.annotationHistory) > 50
                app.annotationHistory = app.annotationHistory(2:end);
                app.historyIndex = app.historyIndex - 1;
            end
        end
    end

    % Component initialization
    methods (Access = public)

        % Construct app
        function app = WaferMapAnnotator

            % Create UIFigure and components
            createComponents(app)

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
            % Clean up polygon visualization
            app.clearPolygonVisualization();
            
            % Clear mouse callbacks
            app.clearMouseCallbacks();
            
            % Clear keyboard callbacks (Enhanced cleanup)
            if isvalid(app.UIFigure)
                app.UIFigure.WindowKeyPressFcn = [];
            end

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
