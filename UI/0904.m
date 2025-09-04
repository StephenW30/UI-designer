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
        
        % Display properties - MODIFIED: Initialize as empty
        pixelSizeMm = []          % Pixel size in mm - NOW EMPTY initially
        waferSizeMM = []          % Wafer size in mm - NOW EMPTY initially  
        flipVertical = true       % Flip image vertically
        bPlotInMm = false         % Plot in mm units
        
        % Annotation properties
        brushMode = false         % Brush annotation mode
        polygonMode = false       % Polygon annotation mode
        brushSize = 3             % Brush size for annotation
        currentLabel = 'PLStar'   % Current selected label
        labelColors               % Colors for each label
        annotationData            % Annotation mask data for each label
        combinedMask              % Combined mask from all labels
        
        % Drawing state
        IsDrawing = false         % Whether currently drawing
        IsInteractiveMode = false % Whether in interactive mode
        
        % Polygon properties
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
            app.UIFigure.Name = 'Wafer Map Annotator (Enhanced - Horizontal Layout)';
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

            % Create PlotInMmCheckBox - MODIFIED: Initially disabled
            app.PlotInMmCheckBox = uicheckbox(app.DisplayGrid);
            app.PlotInMmCheckBox.ValueChangedFcn = createCallbackFcn(app, @PlotInMmCheckBoxValueChanged, true);
            app.PlotInMmCheckBox.Text = 'Plot in mm';
            app.PlotInMmCheckBox.Layout.Row = 1;
            app.PlotInMmCheckBox.Layout.Column = [1 2];
            app.PlotInMmCheckBox.Enable = 'off';  % MODIFIED: Initially disabled

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

            % Create PixelSizeEditField - MODIFIED: Empty initially
            app.PixelSizeEditField = uieditfield(app.DisplayGrid, 'numeric');
            app.PixelSizeEditField.ValueChangedFcn = createCallbackFcn(app, @PixelSizeEditFieldValueChanged, true);
            app.PixelSizeEditField.Value = [];  % MODIFIED: Empty initially
            app.PixelSizeEditField.Layout.Row = 3;
            app.PixelSizeEditField.Layout.Column = 2;
            app.PixelSizeEditField.Tooltip = 'Enter pixel size in mm to enable mm display';

            % Create WaferSizeLabel
            app.WaferSizeLabel = uilabel(app.DisplayGrid);
            app.WaferSizeLabel.Text = 'Wafer Size (mm)';
            app.WaferSizeLabel.Layout.Row = 4;
            app.WaferSizeLabel.Layout.Column = 1;

            % Create WaferSizeEditField - MODIFIED: Empty and disabled initially
            app.WaferSizeEditField = uieditfield(app.DisplayGrid, 'numeric');
            app.WaferSizeEditField.ValueChangedFcn = createCallbackFcn(app, @WaferSizeEditFieldValueChanged, true);
            app.WaferSizeEditField.Value = [];  % MODIFIED: Empty initially
            app.WaferSizeEditField.Enable = 'off';  % MODIFIED: Disabled initially
            app.WaferSizeEditField.Layout.Row = 4;
            app.WaferSizeEditField.Layout.Column = 2;
            app.WaferSizeEditField.Tooltip = 'Auto-calculated after loading image';
        end

        function createImageEnhancement(app)
            % Create EnhancementPanel
            app.EnhancementPanel = uipanel(app.ControlGrid);
            app.EnhancementPanel.Title = '2. Image Enhancement';
            app.EnhancementPanel.Layout.Row = 2;
            app.EnhancementPanel.Layout.Column = 1;

            % Create EnhancementGrid
            app.EnhancementGrid = uigridlayout(app.EnhancementPanel);
            app.EnhancementGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            app.EnhancementGrid.ColumnWidth = {'1x', '1x'};

            % Row 1: Both labels side by side
            app.LowClipLabel = uilabel(app.EnhancementGrid);
            app.LowClipLabel.Text = 'Low Clip (0%)';
            app.LowClipLabel.Layout.Row = 1;
            app.LowClipLabel.Layout.Column = 1;
            app.LowClipLabel.HorizontalAlignment = 'center';

            app.HighClipLabel = uilabel(app.EnhancementGrid);
            app.HighClipLabel.Text = 'High Clip (100%)';
            app.HighClipLabel.Layout.Row = 1;
            app.HighClipLabel.Layout.Column = 2;
            app.HighClipLabel.HorizontalAlignment = 'center';

            % Row 2: Both sliders side by side
            app.LowClipSlider = uislider(app.EnhancementGrid);
            app.LowClipSlider.Limits = [0 50];
            app.LowClipSlider.ValueChangedFcn = createCallbackFcn(app, @LowClipSliderValueChanged, true);
            app.LowClipSlider.Layout.Row = 2;
            app.LowClipSlider.Layout.Column = 1;

            app.HighClipSlider = uislider(app.EnhancementGrid);
            app.HighClipSlider.Limits = [50 100];
            app.HighClipSlider.Value = 100;
            app.HighClipSlider.ValueChangedFcn = createCallbackFcn(app, @HighClipSliderValueChanged, true);
            app.HighClipSlider.Layout.Row = 2;
            app.HighClipSlider.Layout.Column = 2;

            % Row 3: Both value labels side by side
            app.LowClipValueLabel = uilabel(app.EnhancementGrid);
            app.LowClipValueLabel.Text = '0.000';
            app.LowClipValueLabel.Layout.Row = 3;
            app.LowClipValueLabel.Layout.Column = 1;
            app.LowClipValueLabel.HorizontalAlignment = 'center';

            app.HighClipValueLabel = uilabel(app.EnhancementGrid);
            app.HighClipValueLabel.Text = '1.000';
            app.HighClipValueLabel.Layout.Row = 3;
            app.HighClipValueLabel.Layout.Column = 2;
            app.HighClipValueLabel.HorizontalAlignment = 'center';

            % Row 4: Reset button
            app.ResetClipButton = uibutton(app.EnhancementGrid, 'push');
            app.ResetClipButton.ButtonPushedFcn = createCallbackFcn(app, @ResetClipButtonPushed, true);
            app.ResetClipButton.Layout.Row = 4;
            app.ResetClipButton.Layout.Column = [1 2];
            app.ResetClipButton.Text = 'Reset Clipping';
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

            % Create BrushSizeLabel
            app.BrushSizeLabel = uilabel(app.AnnotationControlsGrid);
            app.BrushSizeLabel.Text = 'Brush Size (1)';
            app.BrushSizeLabel.Layout.Row = 1;
            app.BrushSizeLabel.Layout.Column = [1 2];

            % Create BrushSizeSlider
            app.BrushSizeSlider = uislider(app.AnnotationControlsGrid);
            app.BrushSizeSlider.Limits = [1 10];
            app.BrushSizeSlider.Value = 1;
            app.BrushSizeSlider.MajorTicks = 1:10;
            app.BrushSizeSlider.MajorTickLabels = {'1','2','3','4','5','6','7','8','9','10'};
            app.BrushSizeSlider.MinorTicks = [];
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
            app.LabelListBox.Items = {'PLStar'};
            app.LabelListBox.Value = 'PLStar';
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
            app.CurrentLabelDropDown.Items = {'PLStar'};
            app.CurrentLabelDropDown.Value = 'PLStar';
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
            % Initialize default values - MODIFIED
            app.flipVertical = true;
            app.bPlotInMm = false;
            app.brushSize = 1;
            app.currentLabel = 'PLStar';
            app.brushMode = false;
            app.polygonMode = false;
            
            % Initialize drawing state
            app.IsDrawing = false;
            app.IsInteractiveMode = false;
            app.PolygonPoints = [];
            app.PolygonHandles = [];
            app.IsPolygonActive = false;
            app.PolygonCloseTolerance = 2;
            
            % Initialize label colors
            app.labelColors = containers.Map();
            app.labelColors('PLStar') = [0.74 0.12 0.12];
            
            % Initialize annotation data
            app.annotationData = containers.Map();
            app.combinedMask = [];
            
            % Initialize history
            app.annotationHistory = {};
            app.historyIndex = 0;
            
            % Initialize Cancel Polygon button state
            app.CancelPolygonButton.Enable = 'off';
            app.CancelPolygonButton.BackgroundColor = [0.94 0.94 0.94];
            app.CancelPolygonButton.Text = 'Cancel Polygon';
            
            % Update status - MODIFIED
            app.StatusLabel.Text = 'Please enter pixel size (mm) first, then select a folder.';
            
            fprintf('\n=== Enhanced Wafer Map Annotator (Modified Display Settings) ===\n');
            fprintf('Changes:\n');
            fprintf('1. Pixel Size field starts empty - user must input value\n');
            fprintf('2. Wafer Size field disabled and auto-calculated from image\n');
            fprintf('3. Plot in mm checkbox disabled until pixel size is entered\n');
            fprintf('4. Wafer size auto-calculated after loading image\n');
            fprintf('\nPlease enter pixel size first, then load an image folder.\n');
        end
    end

    % Callbacks that handle component events
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

        % Value changed function: PixelSizeEditField - MODIFIED
        function PixelSizeEditFieldValueChanged(app, event)
            newValue = app.PixelSizeEditField.Value;
            
            % Check if value is valid
            if isempty(newValue) || isnan(newValue) || newValue <= 0
                app.StatusLabel.Text = 'Please enter a valid positive pixel size in mm';
                app.PlotInMmCheckBox.Enable = 'off';
                app.pixelSizeMm = [];
                return;
            end
            
            app.pixelSizeMm = newValue;
            
            % Enable Plot in mm checkbox
            app.PlotInMmCheckBox.Enable = 'on';
            
            % If we have an image loaded, recalculate wafer size
            if ~isempty(app.workingMap)
                [h, w] = size(app.workingMap);
                app.waferSizeMM = w * app.pixelSizeMm;
                app.WaferSizeEditField.Value = app.waferSizeMM;
                fprintf('Wafer size recalculated: %.2f mm (based on %d pixels × %.4f mm/pixel)\n', ...
                    app.waferSizeMM, w, app.pixelSizeMm);
            end
            
            app.StatusLabel.Text = sprintf('Pixel size set to %.4f mm', app.pixelSizeMm);
            updateDisplay(app);
        end

        % Value changed function: WaferSizeEditField - MODIFIED
        function WaferSizeEditFieldValueChanged(app, event)
            % This field is now read-only
            if app.WaferSizeEditField.Enable == "on"
                app.waferSizeMM = app.WaferSizeEditField.Value;
                updateDisplay(app);
            else
                % Restore calculated value
                if ~isempty(app.workingMap) && ~isempty(app.pixelSizeMm)
                    [h, w] = size(app.workingMap);
                    app.waferSizeMM = w * app.pixelSizeMm;
                    app.WaferSizeEditField.Value = app.waferSizeMM;
                end
            end
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

        % Value changed function: BrushSizeSlider
        function BrushSizeSliderValueChanged(app, event)
            sliderValue = round(app.BrushSizeSlider.Value);
            if sliderValue ~= app.BrushSizeSlider.Value
                app.BrushSizeSlider.Value = sliderValue;
            end
            app.brushSize = sliderValue;
            app.BrushSizeLabel.Text = sprintf('Brush Size (%d)', app.brushSize);
            fprintf('Brush size changed to: %d\n', app.brushSize);
        end

        % Value changed function: BrushModeButton
        function BrushModeButtonValueChanged(app, event)
            app.brushMode = app.BrushModeButton.Value;
            if app.brushMode
                app.polygonMode = false;
                app.PolygonModeButton.Value = false;
                app.cancelCurrentPolygon();
                
                try
                    app.UIFigure.WindowButtonDownFcn = @(~,~) app.startDrawing();
                    app.UIFigure.WindowButtonMotionFcn = @(~,~) app.continueDrawing();
                    app.UIFigure.WindowButtonUpFcn = @(~,~) app.stopDrawing();
                    app.HazemapUIAxes.ButtonDownFcn = @(~,~) app.singleClickDraw();
                    
                    app.StatusLabel.Text = 'Brush mode ACTIVE - Click and drag on hazemap to annotate';
                    fprintf('Brush mode enabled\n');
                catch ME
                    app.StatusLabel.Text = sprintf('Error setting up brush mode: %s', ME.message);
                end
            else
                app.StatusLabel.Text = 'Brush mode disabled';
                app.clearMouseCallbacks();
                fprintf('Brush mode disabled\n');
            end
        end

        % Value changed function: PolygonModeButton
        function PolygonModeButtonValueChanged(app, event)
            app.polygonMode = app.PolygonModeButton.Value;
            if app.polygonMode
                app.brushMode = false;
                app.BrushModeButton.Value = false;
                
                app.PolygonPoints = [];
                app.IsPolygonActive = false;
                app.clearPolygonVisualization();
                
                app.CancelPolygonButton.Enable = 'on';
                app.CancelPolygonButton.BackgroundColor = [1 0.9 0.6];
                app.CancelPolygonButton.Text = 'Cancel Polygon (ESC)';
                
                try
                    app.clearMouseCallbacks();
                    app.UIFigure.WindowButtonDownFcn = @(~,~) app.startPolygonDrawing();
                    app.UIFigure.WindowKeyPressFcn = @(~,evt) app.handleKeyPress(evt);
                    
                    app.StatusLabel.Text = 'Polygon mode ACTIVE - Click to add points, ESC to cancel';
                    fprintf('Polygon mode enabled\n');
                catch ME
                    app.StatusLabel.Text = sprintf('Error setting up polygon mode: %s', ME.message);
                end
            else
                app.StatusLabel.Text = 'Polygon mode disabled';
                app.cancelCurrentPolygon();
                app.clearMouseCallbacks();
                app.UIFigure.WindowKeyPressFcn = [];
                
                app.CancelPolygonButton.Enable = 'off';
                app.CancelPolygonButton.BackgroundColor = [0.94 0.94 0.94];
                app.CancelPolygonButton.Text = 'Cancel Polygon';
                
                fprintf('Polygon mode disabled\n');
            end
        end

        % Button pushed function: CancelPolygonButton
        function CancelPolygonButtonPushed(app, event)
            if app.polygonMode
                pointCount = 0;
                if ~isempty(app.PolygonPoints)
                    pointCount = size(app.PolygonPoints, 1);
                end
                
                app.cancelCurrentPolygon();
                
                if pointCount > 0
                    app.StatusLabel.Text = sprintf('Polygon with %d points cancelled', pointCount);
                else
                    app.StatusLabel.Text = 'Ready to start new polygon';
                end
                
                fprintf('Polygon cancelled (had %d points)\n', pointCount);
                
                originalColor = app.CancelPolygonButton.BackgroundColor;
                app.CancelPolygonButton.BackgroundColor = [0.8 1 0.8];
                drawnow;
                pause(0.2);
                app.CancelPolygonButton.BackgroundColor = originalColor;
            else
                app.StatusLabel.Text = 'Cancel polygon is only available in polygon mode';
            end
        end

        % Button pushed function: ClearMaskButton
        function ClearMaskButtonPushed(app, event)
            if ~isempty(app.annotationData)
                labelKeys = app.annotationData.keys;
                for i = 1:length(labelKeys)
                    app.annotationData(labelKeys{i}) = false(size(app.workingMap));
                end
                app.combinedMask = false(size(app.workingMap));
                
                saveToHistory(app);
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                
                app.StatusLabel.Text = 'All annotations cleared';
            end
        end

        % Button pushed function: TestClickButton
        function TestClickButtonPushed(app, event)
            if isempty(app.workingMap)
                app.StatusLabel.Text = 'Please load an image first';
                return;
            end
            
            app.clearMouseCallbacks();
            app.UIFigure.WindowButtonDownFcn = @(~,~) app.testClickEvent();
            app.HazemapUIAxes.ButtonDownFcn = @(~,~) app.testClickAxes();
            
            app.StatusLabel.Text = 'TEST MODE: Click on the hazemap to test';
        end

        % Button pushed function: UndoButton
        function UndoButtonPushed(app, event)
            if app.historyIndex > 1
                app.historyIndex = app.historyIndex - 1;
                
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
                    app.labelColors(newLabel) = rand(1,3);
                    
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
                app.LabelListBox.Items(strcmp(app.LabelListBox.Items, selectedLabel)) = [];
                app.CurrentLabelDropDown.Items(strcmp(app.CurrentLabelDropDown.Items, selectedLabel)) = [];
                
                if app.labelColors.isKey(selectedLabel)
                    app.labelColors.remove(selectedLabel);
                end
                if app.annotationData.isKey(selectedLabel)
                    app.annotationData.remove(selectedLabel);
                end
                
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

        % File management callbacks - MODIFIED
        function SelectFolderButtonPushed(app, event)
            % Check if pixel size has been entered
            if isempty(app.pixelSizeMm)
                app.StatusLabel.Text = 'Please enter pixel size (mm) before selecting folder';
                uialert(app.UIFigure, 'Please enter the pixel size in mm before loading images.', ...
                    'Pixel Size Required', 'Icon', 'warning');
                return;
            end
            
            folder = uigetdir('', 'Select folder containing .mat files');
            if folder ~= 0
                app.selectedFolder = folder;
                
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
                
                updateCombinedMask(app);
                maskMap = app.combinedMask;
                
                if ~isempty(app.workingMap)
                    [h, w] = size(app.workingMap);
                    fprintf('Saving binary mask: %dx%d\n', h, w);
                end
                
                saveFile = fullfile(app.selectedFolder, [name '_mask.mat']);
                save(saveFile, 'maskMap');
                
                app.StatusLabel.Text = sprintf('Binary mask saved to %s', saveFile);
                
                annotatedPixels = sum(maskMap(:));
                totalPixels = numel(maskMap);
                percentage = (annotatedPixels / totalPixels) * 100;
                fprintf('Mask saved: %d pixels annotated (%.2f%% coverage)\n', annotatedPixels, percentage);
            else
                app.StatusLabel.Text = 'No annotation data to save';
            end
        end
    end

    % Drawing methods
    methods (Access = private)
        
        function startDrawing(app)
            if ~app.brushMode || ~app.isMouseInImageArea()
                return;
            end
            
            app.IsDrawing = true;
            fprintf('\n*** Starting brush drawing ***\n');
            app.drawAtCurrentMousePosition();
            app.StatusLabel.Text = sprintf('Drawing with brush on %s...', app.currentLabel);
        end
        
        function continueDrawing(app)
            if app.brushMode && app.IsDrawing && app.isMouseInImageArea()
                app.drawAtCurrentMousePosition();
                fprintf('.');
            end
        end
        
        function stopDrawing(app)
            if app.brushMode && app.IsDrawing
                app.IsDrawing = false;
                fprintf('\n*** Brush drawing completed ***\n');
                app.StatusLabel.Text = sprintf('Brush stroke completed on %s', app.currentLabel);
                
                tempBrushes = findobj(app.HazemapUIAxes, 'Tag', 'TempBrush');
                delete(tempBrushes);
                
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                saveToHistory(app);
            end
        end
        
        function singleClickDraw(app)
            if app.brushMode && app.isMouseInImageArea()
                fprintf('\n*** Single click draw ***\n');
                app.drawAtCurrentMousePosition();
                app.StatusLabel.Text = sprintf('Single click annotation on %s', app.currentLabel);
                saveToHistory(app);
            end
        end
        
        function startPolygonDrawing(app)
            if ~app.polygonMode || ~app.isMouseInImageArea()
                return;
            end
            
            pos = app.HazemapUIAxes.CurrentPoint;
            x = pos(1,1);
            y = pos(1,2);
            
            app.addPolygonPoint(x, y);
        end
        
        function addPolygonPoint(app, x, y)
            try
                if isempty(app.PolygonPoints)
                    app.PolygonPoints = [x, y];
                    app.IsPolygonActive = true;
                    
                    app.CancelPolygonButton.BackgroundColor = [1 0.7 0.7];
                    app.CancelPolygonButton.Text = sprintf('Cancel Polygon (%d pts)', 1);
                    
                    fprintf('Adding polygon starting point: (%.1f, %.1f)\n', x, y);
                    app.StatusLabel.Text = sprintf('Polygon started at (%.1f, %.1f)', x, y);
                else
                    startPoint = app.PolygonPoints(1, :);
                    distance = sqrt((x - startPoint(1))^2 + (y - startPoint(2))^2);
                    
                    if distance <= app.PolygonCloseTolerance && size(app.PolygonPoints, 1) >= 3
                        fprintf('Polygon closed! Generating mask...\n');
                        app.generatePolygonMask();
                        app.StatusLabel.Text = sprintf('Polygon completed and added to %s', app.currentLabel);
                        return;
                    end
                    
                    app.PolygonPoints = [app.PolygonPoints; x, y];
                    pointCount = size(app.PolygonPoints, 1);
                    
                    app.CancelPolygonButton.Text = sprintf('Cancel Polygon (%d pts)', pointCount);
                    
                    fprintf('Adding polygon point %d: (%.1f, %.1f)\n', pointCount, x, y);
                    app.StatusLabel.Text = sprintf('Added %d points', pointCount);
                end
                
                app.updatePolygonVisualization();
                
            catch ME
                fprintf('Error adding polygon point: %s\n', ME.message);
                app.StatusLabel.Text = sprintf('Error: %s', ME.message);
            end
        end
        
        function generatePolygonMask(app)
            try
                if size(app.PolygonPoints, 1) < 3
                    fprintf('Not enough polygon points\n');
                    return;
                end
                
                [h, w] = size(app.workingMap);
                
                if app.bPlotInMm && ~isempty(app.pixelSizeMm)
                    centerPixel = w / 2;
                    xPixels = app.PolygonPoints(:,1) / app.pixelSizeMm + centerPixel + 0.5;
                    yPixels = app.PolygonPoints(:,2) / app.pixelSizeMm + centerPixel + 0.5;
                else
                    xPixels = app.PolygonPoints(:,1);
                    yPixels = app.PolygonPoints(:,2);
                end
                
                xPixels = max(1, min(w, xPixels));
                yPixels = max(1, min(h, yPixels));
                
                polygonMask = poly2mask(xPixels, yPixels, h, w);
                
                if app.annotationData.isKey(app.currentLabel)
                    app.annotationData(app.currentLabel) = app.annotationData(app.currentLabel) | polygonMask;
                else
                    app.annotationData(app.currentLabel) = polygonMask;
                end
                
                if app.polygonMode
                    app.CancelPolygonButton.BackgroundColor = [0.8 1 0.8];
                    app.CancelPolygonButton.Text = 'Polygon Complete!';
                    drawnow;
                end
                
                updateHazemapDisplay(app);
                updateAnnotationDisplay(app);
                
                if app.polygonMode
                    pause(0.3);
                    app.CancelPolygonButton.BackgroundColor = [1 0.9 0.6];
                    app.CancelPolygonButton.Text = 'Cancel Polygon (ESC)';
                end
                
                app.cancelCurrentPolygon();
                saveToHistory(app);
                
                fprintf('Polygon mask generated with %d pixels\n', sum(polygonMask(:)));
                
            catch ME
                fprintf('Error generating polygon mask: %s\n', ME.message);
                app.StatusLabel.Text = sprintf('Error: %s', ME.message);
            end
        end
        
        function updatePolygonVisualization(app)
            try
                app.clearPolygonVisualization();
                
                if isempty(app.PolygonPoints)
                    return;
                end
                
                hold(app.HazemapUIAxes, 'on');
                
                app.PolygonHandles.points = plot(app.HazemapUIAxes, ...
                    app.PolygonPoints(:, 1), app.PolygonPoints(:, 2), ...
                    'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'red');
                
                if size(app.PolygonPoints, 1) >= 1
                    app.PolygonHandles.startPoint = plot(app.HazemapUIAxes, ...
                        app.PolygonPoints(1, 1), app.PolygonPoints(1, 2), ...
                        'go', 'MarkerSize', 12, 'MarkerFaceColor', 'green', 'LineWidth', 2);
                end
                
                if size(app.PolygonPoints, 1) >= 2
                    app.PolygonHandles.lines = plot(app.HazemapUIAxes, ...
                        app.PolygonPoints(:, 1), app.PolygonPoints(:, 2), ...
                        'b-', 'LineWidth', 2);
                end
                
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
            cancelledPoints = 0;
            if ~isempty(app.PolygonPoints)
                cancelledPoints = size(app.PolygonPoints, 1);
            end
            
            app.PolygonPoints = [];
            app.IsPolygonActive = false;
            app.clearPolygonVisualization();
            
            if app.polygonMode
                app.CancelPolygonButton.BackgroundColor = [1 0.9 0.6];
                app.CancelPolygonButton.Text = 'Cancel Polygon (ESC)';
            end
            
            fprintf('Cancelled polygon with %d points\n', cancelledPoints);
        end
        
        function clearMouseCallbacks(app)
            app.UIFigure.WindowButtonDownFcn = [];
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
            app.HazemapUIAxes.ButtonDownFcn = [];
        end
        
        function handleKeyPress(app, eventData)
            switch eventData.Key
                case 'escape'
                    if app.polygonMode && app.IsPolygonActive
                        pointCount = 0;
                        if ~isempty(app.PolygonPoints)
                            pointCount = size(app.PolygonPoints, 1);
                        end
                        app.cancelCurrentPolygon();
                        app.StatusLabel.Text = sprintf('Polygon with %d points cancelled', pointCount);
                        fprintf('Polygon cancelled with ESC\n');
                    end
                case 'return'
                    if app.polygonMode && size(app.PolygonPoints, 1) >= 3
                        app.generatePolygonMask();
                        app.StatusLabel.Text = 'Polygon closed with Enter';
                        fprintf('Polygon closed with Enter\n');
                    elseif app.polygonMode && ~isempty(app.PolygonPoints)
                        app.StatusLabel.Text = sprintf('Need at least 3 points (have %d)', size(app.PolygonPoints, 1));
                    end
            end
        end
        
        function inArea = isMouseInImageArea(app)
            try
                pos = app.HazemapUIAxes.CurrentPoint;
                x = pos(1,1);
                y = pos(1,2);
                
                if app.bPlotInMm && ~isempty(app.pixelSizeMm) && ~isempty(app.waferSizeMM)
                    maxCoord = app.waferSizeMM / 2;
                    inMmBounds = (x >= -maxCoord && x <= maxCoord && y >= -maxCoord && y <= maxCoord);
                    xLimits = app.HazemapUIAxes.XLim;
                    yLimits = app.HazemapUIAxes.YLim;
                    inAxesView = (x >= xLimits(1) && x <= xLimits(2) && y >= yLimits(1) && y <= yLimits(2));
                    inArea = inMmBounds && inAxesView;
                else
                    [h, w] = size(app.workingMap);
                    inArea = (x >= 1 && x <= w && y >= 1 && y <= h);
                    xLimits = app.HazemapUIAxes.XLim;
                    yLimits = app.HazemapUIAxes.YLim;
                    inAxesView = (x >= xLimits(1) && x <= xLimits(2) && y >= yLimits(1) && y <= yLimits(2));
                    inArea = inArea && inAxesView;
                end
            catch
                inArea = false;
            end
        end
        
        function drawAtCurrentMousePosition(app)
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
            if isempty(app.workingMap)
                return;
            end
            
            [h, w] = size(app.workingMap);
            
            if app.bPlotInMm && ~isempty(app.pixelSizeMm)
                centerPixel = w / 2;
                xPixel = round(x / app.pixelSizeMm + centerPixel + 0.5);
                yPixel = round(y / app.pixelSizeMm + centerPixel + 0.5);
            else
                xPixel = round(x);
                yPixel = round(y);
            end
            
            if xPixel >= 1 && xPixel <= w && yPixel >= 1 && yPixel <= h
                [meshX, meshY] = meshgrid(1:w, 1:h);
                distances = sqrt((meshX - xPixel).^2 + (meshY - yPixel).^2);
                brushMask = distances <= app.brushSize/2;
                
                if app.annotationData.isKey(app.currentLabel)
                    app.annotationData(app.currentLabel) = app.annotationData(app.currentLabel) | brushMask;
                else
                    app.annotationData(app.currentLabel) = brushMask;
                end
                
                if app.IsDrawing
                    app.addBrushOverlayFast(x, y);
                else
                    updateHazemapDisplay(app);
                    updateAnnotationDisplay(app);
                end
                
                fprintf('Drew at position (%.1f, %.1f) with %d pixels\n', x, y, sum(brushMask(:)));
            else
                fprintf('Position (%.1f, %.1f) outside bounds\n', x, y);
            end
        end
        
        function addBrushOverlayFast(app, x, y)
            try
                hold(app.HazemapUIAxes, 'on');
                
                if app.labelColors.isKey(app.currentLabel)
                    color = app.labelColors(app.currentLabel);
                else
                    color = [0.74 0.12 0.12];
                end
                
                if app.bPlotInMm && ~isempty(app.pixelSizeMm)
                    brushRadius = (app.brushSize / 2) * app.pixelSizeMm;
                else
                    brushRadius = app.brushSize / 2;
                end

                theta = linspace(0, 2*pi, 50);
                brushX = x + brushRadius * cos(theta);
                brushY = y + brushRadius * sin(theta);

                fill(app.HazemapUIAxes, brushX, brushY, color, 'EdgeColor', 'none', 'Tag', 'TempBrush');
                hold(app.HazemapUIAxes, 'off');
                
            catch ME
                fprintf('Error in fast overlay: %s\n', ME.message);
            end
        end
        
        function testClickEvent(app)
            try
                if app.isMouseInImageArea()
                    pos = app.HazemapUIAxes.CurrentPoint;
                    app.StatusLabel.Text = sprintf('✅ UIFigure click at (%.1f, %.1f)', pos(1,1), pos(1,2));
                    fprintf('UIFigure click test successful\n');
                else
                    app.StatusLabel.Text = '⚠️ Click outside image area';
                end
                
                pause(2);
                app.clearMouseCallbacks();
                app.StatusLabel.Text = 'Test completed';
            catch ME
                app.StatusLabel.Text = sprintf('❌ Error: %s', ME.message);
            end
        end
        
        function testClickAxes(app)
            try
                pos = app.HazemapUIAxes.CurrentPoint;
                app.StatusLabel.Text = sprintf('✅ UIAxes click at (%.1f, %.1f)', pos(1,1), pos(1,2));
                fprintf('UIAxes click test successful\n');
                
                pause(2);
                app.clearMouseCallbacks();
                app.StatusLabel.Text = 'Test completed';
            catch ME
                app.StatusLabel.Text = sprintf('❌ Error: %s', ME.message);
            end
        end
    end

    % Helper methods - MODIFIED
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
                        
                        % MODIFIED: Calculate wafer size
                        if ~isempty(app.pixelSizeMm)
                            [h, w] = size(app.originalMap);
                            app.waferSizeMM = w * app.pixelSizeMm;
                            app.WaferSizeEditField.Value = app.waferSizeMM;
                            
                            fprintf('Image loaded: %dx%d pixels\n', h, w);
                            fprintf('Wafer size calculated: %.2f mm × %.2f mm\n', ...
                                w * app.pixelSizeMm, h * app.pixelSizeMm);
                            fprintf('Using wafer diameter: %.2f mm\n', app.waferSizeMM);
                        end
                        
                        setupImageDisplay(app);
                        updateDisplay(app);
                        app.CurrentFileLabel.Text = currentFile;
                        
                        app.annotationData = containers.Map();
                        keys = app.labelColors.keys;
                        for i = 1:length(keys)
                            app.annotationData(keys{i}) = false(size(app.originalMap));
                        end
                        
                        app.combinedMask = false(size(app.originalMap));
                        
                        app.annotationHistory = {};
                        app.historyIndex = 0;
                        saveToHistory(app);
                        
                        app.brushMode = false;
                        app.polygonMode = false;
                        app.BrushModeButton.Value = false;
                        app.PolygonModeButton.Value = false;
                        app.cancelCurrentPolygon();
                        app.clearMouseCallbacks();
                        
                        app.StatusLabel.Text = sprintf('Loaded %d/%d: %s (Wafer: %.1fmm)', ...
                            app.currentImageIndex, length(app.imageFiles), currentFile, app.waferSizeMM);
                    else
                        app.StatusLabel.Text = 'File does not contain dw_image field';
                    end
                catch ME
                    app.StatusLabel.Text = sprintf('Error loading file: %s', ME.message);
                end
            end
        end
        
        function setupImageDisplay(app)
            if ~isempty(app.workingMap)
                fprintf('Setting up image display...\n');
                app.HazemapUIAxes.XTick = [];
                app.HazemapUIAxes.YTick = [];
                app.HazemapUIAxes.Box = 'on';
                fprintf('Image display setup complete\n');
            end
        end
        
        function processImageData(app)
            if ~isempty(app.originalMap)
                if app.flipVertical
                    app.workingMap = flipud(app.originalMap);
                else
                    app.workingMap = app.originalMap;
                end
                
                app.workingMap(app.workingMap == 0 | app.workingMap == min(app.workingMap(:))) = NaN;
                app.validData = app.workingMap(~isnan(app.workingMap));
                
                updateClipping(app);
            end
        end
        
        function updateClipping(app)
            if isempty(app.validData)
                return;
            end
            
            lowClipPercent = app.LowClipSlider.Value;
            highClipPercent = app.HighClipSlider.Value;
            
            if lowClipPercent >= highClipPercent - 1
                if lowClipPercent >= 49
                    app.LowClipSlider.Value = highClipPercent - 1;
                    lowClipPercent = highClipPercent - 1;
                else
                    app.HighClipSlider.Value = lowClipPercent + 1;
                    highClipPercent = lowClipPercent + 1;
                end
            end
            
            lowClip = prctile(app.validData, lowClipPercent);
            highClip = prctile(app.validData, highClipPercent);
            
            app.LowClipLabel.Text = sprintf('Low Clip (%.1f%%)', lowClipPercent);
            app.HighClipLabel.Text = sprintf('High Clip (%.1f%%)', highClipPercent);
            app.LowClipValueLabel.Text = sprintf('%.3f', lowClip);
            app.HighClipValueLabel.Text = sprintf('%.3f', highClip);
            
            if ~isempty(app.hazemapImageHandle) && isvalid(app.hazemapImageHandle)
                app.hazemapImageHandle.CData = app.workingMap;
                clim(app.HazemapUIAxes, [lowClip, highClip]);
            end
        end
        
        function updateDisplay(app)
            if isempty(app.workingMap)
                return;
            end
            
            updateHazemapDisplay(app);
            updateAnnotationDisplay(app);
        end
        
        function updateHazemapDisplay(app)
            if isempty(app.workingMap)
                return;
            end
            
            [h, w] = size(app.workingMap);
            
            if app.bPlotInMm && ~isempty(app.pixelSizeMm)
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
            
            currentWindowDown = app.UIFigure.WindowButtonDownFcn;
            currentWindowMotion = app.UIFigure.WindowButtonMotionFcn;
            currentWindowUp = app.UIFigure.WindowButtonUpFcn;
            currentAxesDown = app.HazemapUIAxes.ButtonDownFcn;
            
            currentXLim = [];
            currentYLim = [];
            shouldRestoreZoom = false;
            
            if ~isempty(app.hazemapImageHandle) && isvalid(app.hazemapImageHandle)
                try
                    currentXLim = app.HazemapUIAxes.XLim;
                    currentYLim = app.HazemapUIAxes.YLim;
                    
                    if all(isfinite([currentXLim, currentYLim])) && ...
                       currentXLim(1) ~= currentXLim(2) && currentYLim(1) ~= currentYLim(2)
                        if app.bPlotInMm && ~isempty(app.pixelSizeMm)
                            imageXRange = [min(xCoord), max(xCoord)];
                            imageYRange = [min(yCoord), max(yCoord)];
                        else
                            imageXRange = [1, w];
                            imageYRange = [1, h];
                        end
                        
                        if (currentXLim(2) - currentXLim(1)) < 0.9 * (imageXRange(2) - imageXRange(1)) || ...
                           (currentYLim(2) - currentYLim(1)) < 0.9 * (imageYRange(2) - imageYRange(1))
                            shouldRestoreZoom = true;
                        end
                    end
                catch
                    shouldRestoreZoom = false;
                end
            end
            
            if isempty(app.hazemapImageHandle) || ~isvalid(app.hazemapImageHandle)
                cla(app.HazemapUIAxes);
                needsFullRedraw = true;
            else
                children = app.HazemapUIAxes.Children;
                for i = 1:length(children)
                    if children(i) ~= app.hazemapImageHandle
                        delete(children(i));
                    end
                end
                needsFullRedraw = false;
            end
            
            if needsFullRedraw
                app.hazemapImageHandle = imagesc(app.HazemapUIAxes, xCoord, yCoord, app.workingMap);
                colormap(app.HazemapUIAxes, 'jet');
                colorbar(app.HazemapUIAxes);
                axis(app.HazemapUIAxes, 'equal');
                axis(app.HazemapUIAxes, 'xy');
                app.HazemapUIAxes.XLabel.String = xLabelText;
                app.HazemapUIAxes.YLabel.String = yLabelText;
                axis(app.HazemapUIAxes, 'tight');
            else
                app.hazemapImageHandle.CData = app.workingMap;
                app.hazemapImageHandle.XData = xCoord;
                app.hazemapImageHandle.YData = yCoord;
                app.HazemapUIAxes.XLabel.String = xLabelText;
                app.HazemapUIAxes.YLabel.String = yLabelText;
            end
            
            app.UIFigure.WindowButtonDownFcn = currentWindowDown;
            app.UIFigure.WindowButtonMotionFcn = currentWindowMotion;
            app.UIFigure.WindowButtonUpFcn = currentWindowUp;
            app.HazemapUIAxes.ButtonDownFcn = currentAxesDown;
            
            hold(app.HazemapUIAxes, 'on');
            if ~isempty(app.annotationData)
                labelKeys = app.annotationData.keys;
                for i = 1:length(labelKeys)
                    mask = app.annotationData(labelKeys{i});
                    if any(mask(:))
                        color = app.labelColors(labelKeys{i});
                        overlayRGB = cat(3, color(1)*double(mask), color(2)*double(mask), color(3)*double(mask));
                        h_overlay = imagesc(app.HazemapUIAxes, xCoord, yCoord, overlayRGB);
                        h_overlay.AlphaData = 0.5 * double(mask);
                        h_overlay.HitTest = 'off';
                    end
                end
            end
            hold(app.HazemapUIAxes, 'off');
            
            if shouldRestoreZoom && ~isempty(currentXLim) && ~isempty(currentYLim)
                app.HazemapUIAxes.XLim = currentXLim;
                app.HazemapUIAxes.YLim = currentYLim;
                fprintf('Zoom state restored\n');
            else
                fprintf('No zoom to restore\n');
            end
            
            title(app.HazemapUIAxes, 'Hazemap with Annotations');
            
            if ~isempty(app.CurrentFileLabel) && ~strcmp(app.CurrentFileLabel.Text, 'No file selected')
                title(app.HazemapUIAxes, sprintf('Hazemap: %s', app.CurrentFileLabel.Text));
            end
            
            fprintf('Hazemap display updated\n');
        end
        
        function updateAnnotationDisplay(app)
            if isempty(app.workingMap)
                return;
            end
            
            [h, w] = size(app.workingMap);
            
            if app.bPlotInMm && ~isempty(app.pixelSizeMm)
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
            
            currentXLim = [];
            currentYLim = [];
            shouldRestoreZoom = false;
            
            if ~isempty(app.annotationImageHandle) && isvalid(app.annotationImageHandle)
                try
                    currentXLim = app.AnnotationUIAxes.XLim;
                    currentYLim = app.AnnotationUIAxes.YLim;
                    
                    if all(isfinite([currentXLim, currentYLim])) && ...
                       currentXLim(1) ~= currentXLim(2) && currentYLim(1) ~= currentYLim(2)
                        if app.bPlotInMm && ~isempty(app.pixelSizeMm)
                            imageXRange = [min(xCoord), max(xCoord)];
                            imageYRange = [min(yCoord), max(yCoord)];
                        else
                            imageXRange = [1, w];
                            imageYRange = [1, h];
                        end
                        
                        if (currentXLim(2) - currentXLim(1)) < 0.9 * (imageXRange(2) - imageXRange(1)) || ...
                           (currentYLim(2) - currentYLim(1)) < 0.9 * (imageYRange(2) - imageYRange(1))
                            shouldRestoreZoom = true;
                        end
                    end
                catch
                    shouldRestoreZoom = false;
                end
            end
            
            updateCombinedMask(app);
            maskDisplay = double(app.combinedMask);
            
            cla(app.AnnotationUIAxes);
            app.annotationImageHandle = imagesc(app.AnnotationUIAxes, xCoord, yCoord, maskDisplay);
            colormap(app.AnnotationUIAxes, [0 0 0; 1 1 1]);
            axis(app.AnnotationUIAxes, 'equal');
            axis(app.AnnotationUIAxes, 'xy');
            app.AnnotationUIAxes.XLabel.String = xLabelText;
            app.AnnotationUIAxes.YLabel.String = yLabelText;
            axis(app.AnnotationUIAxes, 'tight');
            
            if shouldRestoreZoom && ~isempty(currentXLim) && ~isempty(currentYLim)
                app.AnnotationUIAxes.XLim = currentXLim;
                app.AnnotationUIAxes.YLim = currentYLim;
            end
            
            annotatedPixels = sum(app.combinedMask(:));
            totalPixels = numel(app.combinedMask);
            percentage = (annotatedPixels / totalPixels) * 100;
            
            title(app.AnnotationUIAxes, sprintf('Annotation Mask (%.1f%% covered)', percentage));
            
            linkaxes([app.HazemapUIAxes, app.AnnotationUIAxes], 'xy');
            
            fprintf('Annotation display updated\n');
        end
        
        function updateCombinedMask(app)
            if isempty(app.annotationData) || isempty(app.workingMap)
                app.combinedMask = false(size(app.workingMap));
                return;
            end
            
            app.combinedMask = false(size(app.workingMap));
            labelKeys = app.annotationData.keys;
            for i = 1:length(labelKeys)
                if app.annotationData.isKey(labelKeys{i})
                    app.combinedMask = app.combinedMask | app.annotationData(labelKeys{i});
                end
            end
        end
        
        function saveToHistory(app)
            if app.historyIndex < length(app.annotationHistory)
                app.annotationHistory = app.annotationHistory(1:app.historyIndex);
            end
            
            currentStateCopy = containers.Map();
            if ~isempty(app.annotationData)
                keys = app.annotationData.keys;
                for i = 1:length(keys)
                    currentStateCopy(keys{i}) = app.annotationData(keys{i});
                end
            end
            
            app.annotationHistory{end+1} = currentStateCopy;
            app.historyIndex = length(app.annotationHistory);
            
            if length(app.annotationHistory) > 50
                app.annotationHistory = app.annotationHistory(2:end);
                app.historyIndex = app.historyIndex - 1;
            end
            
            fprintf('History saved (step %d/%d)\n', app.historyIndex, length(app.annotationHistory));
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
            app.clearPolygonVisualization();
            app.clearMouseCallbacks();
            
            if isvalid(app.UIFigure)
                app.UIFigure.WindowKeyPressFcn = [];
            end

            delete(app.UIFigure)
        end
    end
end
