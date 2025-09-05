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
        
        % Display properties
        pixelSizeMm               % Pixel size in mm
        waferSizeMM               % Wafer size in mm
        flipVertical = true       % Flip image vertically
        bPlotInMm = false         % Plot in mm units
        
        % New: Zoom state management
        pixelModeXLim = []        % X-axis range in pixel mode
        pixelModeYLim = []        % Y-axis range in pixel mode
        mmModeXLim = []           % X-axis range in mm mode
        mmModeYLim = []           % Y-axis range in mm mode
        hasPixelZoom = false      % Whether pixel mode has custom zoom
        hasMmZoom = false         % Whether mm mode has custom zoom
        
        % Annotation properties
        brushMode = false         % Brush annotation mode
        polygonMode = false       % Polygon annotation mode
        brushSize = 3             % Brush size for annotation
        currentLabel = 'PLStar'   % Current selected label
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
        
        % History for undo/redo (FIXED)
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
            app.UIFigure.Name = 'Wafer Map Annotator';
            app.UIFigure.Resize = 'on';

            % Create MainGrid - 3 columns: Hazemap, Annotation Mask, Control Panel
            app.MainGrid = uigridlayout(app.UIFigure);
            app.MainGrid.ColumnWidth = {'1x', '1x', 350};
            app.MainGrid.RowHeight = {'1x', 100};

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
            app.AnnotationUIAxes.Box = 'on';
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
            app.PixelSizeEditField.AllowEmpty = 'on';
            app.PixelSizeEditField.Value = [];
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
            app.WaferSizeEditField.AllowEmpty = "on";
            app.WaferSizeEditField.Value = [];
            app.WaferSizeEditField.Layout.Row = 4;
            app.WaferSizeEditField.Layout.Column = 2;
        end

        function createImageEnhancement(app)
            % Create EnhancementPanel
            app.EnhancementPanel = uipanel(app.ControlGrid);
            app.EnhancementPanel.Title = '2. Image Enhancement';
            app.EnhancementPanel.Layout.Row = 2;
            app.EnhancementPanel.Layout.Column = 1;

            % Create EnhancementGrid with modified layout for horizontal arrangement
            app.EnhancementGrid = uigridlayout(app.EnhancementPanel);
            app.EnhancementGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            app.EnhancementGrid.ColumnWidth = {'1x', '1x'};  % Two equal columns

            % Row 1: Both labels side by side
            % Create LowClipLabel (Left)
            app.LowClipLabel = uilabel(app.EnhancementGrid);
            app.LowClipLabel.Text = 'Low Clip (0%)';
            app.LowClipLabel.Layout.Row = 1;
            app.LowClipLabel.Layout.Column = 1;
            app.LowClipLabel.HorizontalAlignment = 'center';

            % Create HighClipLabel (Right)
            app.HighClipLabel = uilabel(app.EnhancementGrid);
            app.HighClipLabel.Text = 'High Clip (100%)';
            app.HighClipLabel.Layout.Row = 1;
            app.HighClipLabel.Layout.Column = 2;
            app.HighClipLabel.HorizontalAlignment = 'center';

            % Row 2: Both sliders side by side
            % Create LowClipSlider (Left)
            app.LowClipSlider = uislider(app.EnhancementGrid);
            app.LowClipSlider.Limits = [0 50];
            app.LowClipSlider.ValueChangedFcn = createCallbackFcn(app, @LowClipSliderValueChanged, true);
            app.LowClipSlider.Layout.Row = 2;
            app.LowClipSlider.Layout.Column = 1;

            % Create HighClipSlider (Right)
            app.HighClipSlider = uislider(app.EnhancementGrid);
            app.HighClipSlider.Limits = [50 100];
            app.HighClipSlider.Value = 100;
            app.HighClipSlider.ValueChangedFcn = createCallbackFcn(app, @HighClipSliderValueChanged, true);
            app.HighClipSlider.Layout.Row = 2;
            app.HighClipSlider.Layout.Column = 2;

            % Row 3: Both value labels side by side
            % Create LowClipValueLabel (Left)
            app.LowClipValueLabel = uilabel(app.EnhancementGrid);
            app.LowClipValueLabel.Text = '0.000';
            app.LowClipValueLabel.Layout.Row = 3;
            app.LowClipValueLabel.Layout.Column = 1;
            app.LowClipValueLabel.HorizontalAlignment = 'center';

            % Create HighClipValueLabel (Right)
            app.HighClipValueLabel = uilabel(app.EnhancementGrid);
            app.HighClipValueLabel.Text = '1.000';
            app.HighClipValueLabel.Layout.Row = 3;
            app.HighClipValueLabel.Layout.Column = 2;
            app.HighClipValueLabel.HorizontalAlignment = 'center';

            % Row 4: Reset button centered across both columns
            % Create ResetClipButton
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
            % Initialize default values
            app.pixelSizeMm = [];
            app.waferSizeMM = [];
            app.flipVertical = true;
            app.bPlotInMm = false;
            app.brushSize = 1;
            app.currentLabel = 'PLStar';
            app.brushMode = false;
            app.polygonMode = false;
            
            % Initialize zoom state properties
            app.pixelModeXLim = [];
            app.pixelModeYLim = [];
            app.mmModeXLim = [];
            app.mmModeYLim = [];
            app.hasPixelZoom = false;
            app.hasMmZoom = false;
            
            % *** New: Initially disable Plot in mm checkbox ***
            app.PlotInMmCheckBox.Enable = 'off';
            app.PlotInMmCheckBox.Value = false;
            
            % Initialize drawing state
            app.IsDrawing = false;
            app.IsInteractiveMode = false;
            app.PolygonPoints = [];
            app.PolygonHandles = [];
            app.IsPolygonActive = false;
            app.PolygonCloseTolerance = 3;
            
            % Initialize label colors
            app.labelColors = containers.Map();
            app.labelColors('PLStar') = [0.74 0.12 0.12];
            
            % Initialize annotation data
            app.annotationData = containers.Map();
            app.combinedMask = [];
            
            % Initialize history for undo/redo
            app.annotationHistory = {};
            app.historyIndex = 0;
            
            % Initialize Cancel Polygon button state
            app.CancelPolygonButton.Enable = 'off';
            app.CancelPolygonButton.BackgroundColor = [0.94 0.94 0.94];
            app.CancelPolygonButton.Text = 'Cancel Polygon';
            
            % *** New: Update status message ***
            app.StatusLabel.Text = 'Please enter Pixel Size (mm) or Wafer Size (mm) first, then select a folder.';
            
            fprintf('\n=== Wafer Map Annotator Initialized ===\n');
            fprintf('Note: Please enter pixel size or wafer size before selecting folder.\n');
        end
    end

    % Callbacks that handle component events (main callbacks)
    methods (Access = private)

        % Value changed function: PlotInMmCheckBox (Modified version)
        function PlotInMmCheckBoxValueChanged(app, event)
            % Save current mode's zoom state
            saveCurrentZoomState(app);
            
            % Switch mode
            app.bPlotInMm = app.PlotInMmCheckBox.Value;
            
            % Update display and restore corresponding mode's zoom state
            updateDisplay(app, true);  % Pass true to indicate need to restore zoom
            
            unit = {'pixel','mm'};  % Cell array
            fprintf('Coordinate system switched to %s mode\n', unit{app.bPlotInMm+1});
        end

        % Value changed function: FlipVerticalCheckBox
        function FlipVerticalCheckBoxValueChanged(app, event)
            app.flipVertical = app.FlipVerticalCheckBox.Value;
            if ~isempty(app.originalMap)
                processImageData(app);
                updateDisplay(app, false); % Don't restore zoom
            end
        end

        % Value changed function: PixelSizeEditField
        function PixelSizeEditFieldValueChanged(app, event)
            app.pixelSizeMm = app.PixelSizeEditField.Value;
            
            % Check if mm mode can be enabled
            if validateMmModeParameters(app)
                if app.PlotInMmCheckBox.Enable == "off"
                    % If image is loaded but checkbox is not enabled, trigger parameter calculation
                    calculateMissingParameters(app);
                end
            else
                % If conditions are not met, disable checkbox
                app.PlotInMmCheckBox.Enable = 'off';
                app.PlotInMmCheckBox.Value = false;
                app.bPlotInMm = false;
            end
            
            % If already in mm mode, update display
            if app.bPlotInMm
                updateDisplay(app, false); % Don't restore zoom
            end
        end

        % Value changed function: WaferSizeEditField
        function WaferSizeEditFieldValueChanged(app, event)
            app.waferSizeMM = app.WaferSizeEditField.Value;
            
            % Check if mm mode can be enabled
            if validateMmModeParameters(app)
                if app.PlotInMmCheckBox.Enable == "off"
                    % If image is loaded but checkbox is not enabled, trigger parameter calculation
                    calculateMissingParameters(app);
                end
            else
                % If conditions are not met, disable checkbox
                app.PlotInMmCheckBox.Enable = 'off';
                app.PlotInMmCheckBox.Value = false;
                app.bPlotInMm = false;
            end
            
            % If already in mm mode, update display
            if app.bPlotInMm
                updateDisplay(app, false); % Don't restore zoom
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

        % Button pushed function: ClearMaskButton (Modified version)
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
                
                % Update both displays - don't restore zoom
                updateHazemapDisplay(app, false);
                updateAnnotationDisplay(app, false);
                
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

        % Button pushed function: UndoButton (*** FIXED ***)
        function UndoButtonPushed(app, event)
            if app.historyIndex > 1
                app.historyIndex = app.historyIndex - 1;
                
                % Deep copy historical state
                historicalState = app.annotationHistory{app.historyIndex};
                app.annotationData = containers.Map();
                if ~isempty(historicalState)
                    keys = historicalState.keys;
                    for i = 1:length(keys)
                        app.annotationData(keys{i}) = historicalState(keys{i});
                    end
                end
                
                % Update display - don't restore zoom
                updateHazemapDisplay(app, false);
                updateAnnotationDisplay(app, false);
                app.StatusLabel.Text = sprintf('Undo performed (step %d/%d)', app.historyIndex, length(app.annotationHistory));
            else
                app.StatusLabel.Text = 'Nothing to undo';
            end
        end

        % Button pushed function: RedoButton (*** FIXED ***)
        function RedoButtonPushed(app, event)
            if app.historyIndex < length(app.annotationHistory)
                app.historyIndex = app.historyIndex + 1;
                
                % Deep copy historical state
                historicalState = app.annotationHistory{app.historyIndex};
                app.annotationData = containers.Map();
                if ~isempty(historicalState)
                    keys = historicalState.keys;
                    for i = 1:length(keys)
                        app.annotationData(keys{i}) = historicalState(keys{i});
                    end
                end
                
                % Update display - don't restore zoom
                updateHazemapDisplay(app, false);
                updateAnnotationDisplay(app, false);
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
                % Update display - don't restore zoom
                updateHazemapDisplay(app, false);
                updateAnnotationDisplay(app, false);
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
                    
                    % Load image
                    loadCurrentImage(app);
                    
                    % *** New: After image loading, check and calculate parameters ***
                    if ~isempty(app.workingMap)
                        % Check if size parameters exist
                        hasPixelSize = ~isempty(app.pixelSizeMm) && ~isnan(app.pixelSizeMm) && app.pixelSizeMm > 0;
                        hasWaferSize = ~isempty(app.waferSizeMM) && ~isnan(app.waferSizeMM) && app.waferSizeMM > 0;
                        
                        if hasPixelSize || hasWaferSize
                            % Automatically calculate missing parameters
                            calculateMissingParameters(app);
                            app.StatusLabel.Text = sprintf('Loaded folder with %d files. MM mode available.', length(app.imageFiles));
                        else
                            % Prompt user to enter parameters
                            app.StatusLabel.Text = sprintf('Loaded folder with %d files. Please enter Pixel Size or Wafer Size to enable mm mode.', length(app.imageFiles));
                        end
                    else
                        app.StatusLabel.Text = sprintf('Loaded folder with %d files, but failed to load image', length(app.imageFiles));
                    end
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
                
                % Update combined mask to get the final binary mask
                updateCombinedMask(app);
                
                % Save as binary mask with same size as original image
                % combinedMask is already the same size as workingMap/originalMap
                maskMap = app.combinedMask;
                
                % Verify the size matches the original image
                if ~isempty(app.workingMap)
                    [h, w] = size(app.workingMap);
                    fprintf('Saving binary mask: %dx%d (matches image size)\n', h, w);
                end
                
                % Save the binary mask
                saveFile = fullfile(app.selectedFolder, [name '_mask.mat']);
                save(saveFile, 'maskMap');
                
                % Also save individual label masks if needed (optional)
                labelMasks = app.annotationData;
                labelFile = fullfile(app.selectedFolder, [name '_labels.mat']);
                save(labelFile, 'labelMasks');
                
                app.StatusLabel.Text = sprintf('Binary mask saved to %s', saveFile);
                
                % Display statistics
                annotatedPixels = sum(maskMap(:));
                totalPixels = numel(maskMap);
                percentage = (annotatedPixels / totalPixels) * 100;
                fprintf('Mask saved: %d pixels annotated (%.2f%% coverage)\n', annotatedPixels, percentage);
            else
                app.StatusLabel.Text = 'No annotation data to save';
            end
        end
    end

    % New: Zoom state management methods
    methods (Access = private)
        function saveCurrentZoomState(app)
            % Save zoom state of current mode
            if ~isempty(app.workingMap) && ~isempty(app.hazemapImageHandle) && isvalid(app.hazemapImageHandle)
                try
                    currentXLim = app.HazemapUIAxes.XLim;
                    currentYLim = app.HazemapUIAxes.YLim;
                    
                    if app.bPlotInMm
                        % Currently in mm mode, save mm mode zoom
                        if isZoomedState(app, currentXLim, currentYLim, true)
                            app.mmModeXLim = currentXLim;
                            app.mmModeYLim = currentYLim;
                            app.hasMmZoom = true;
                            fprintf('Saved mm mode zoom state: X[%.2f, %.2f], Y[%.2f, %.2f]\n', ...
                                currentXLim(1), currentXLim(2), currentYLim(1), currentYLim(2));
                        end
                    else
                        % Currently in pixel mode, save pixel mode zoom
                        if isZoomedState(app, currentXLim, currentYLim, false)
                            app.pixelModeXLim = currentXLim;
                            app.pixelModeYLim = currentYLim;
                            app.hasPixelZoom = true;
                            fprintf('Saved pixel mode zoom state: X[%.1f, %.1f], Y[%.1f, %.1f]\n', ...
                                currentXLim(1), currentXLim(2), currentYLim(1), currentYLim(2));
                        end
                    end
                catch ME
                    fprintf('Error saving zoom state: %s\n', ME.message);
                end
            end
        end

        function zoomed = isZoomedState(app, xLim, yLim, isMmMode)
            % Determine if currently in zoomed state
            if any(~isfinite([xLim, yLim])) || xLim(1) == xLim(2) || yLim(1) == yLim(2)
                zoomed = false;
                return;
            end
            
            [h, w] = size(app.workingMap);
            
            if isMmMode
                % Image range in mm mode
                centerPixel = w / 2;
                imageXRange = [((1 - centerPixel - 0.5) * app.pixelSizeMm), ((w - centerPixel - 0.5) * app.pixelSizeMm)];
                imageYRange = [((1 - centerPixel - 0.5) * app.pixelSizeMm), ((h - centerPixel - 0.5) * app.pixelSizeMm)];
            else
                % Image range in pixel mode
                imageXRange = [1, w];
                imageYRange = [1, h];
            end
            
            % If current display range is significantly smaller than image range, consider it zoomed
            xRatio = (xLim(2) - xLim(1)) / (imageXRange(2) - imageXRange(1));
            yRatio = (yLim(2) - yLim(1)) / (imageYRange(2) - imageYRange(1));
            
            zoomed = (xRatio < 0.95) || (yRatio < 0.95);
        end

        function restoreZoomState(app)
            % Restore zoom state of current mode
            try
                if app.bPlotInMm && app.hasMmZoom && ~isempty(app.mmModeXLim)
                    % Restore mm mode zoom
                    app.HazemapUIAxes.XLim = app.mmModeXLim;
                    app.HazemapUIAxes.YLim = app.mmModeYLim;
                    fprintf('Restored mm mode zoom state: X[%.2f, %.2f], Y[%.2f, %.2f]\n', ...
                        app.mmModeXLim(1), app.mmModeXLim(2), app.mmModeYLim(1), app.mmModeYLim(2));
                        
                elseif ~app.bPlotInMm && app.hasPixelZoom && ~isempty(app.pixelModeXLim)
                    % Restore pixel mode zoom
                    app.HazemapUIAxes.XLim = app.pixelModeXLim;
                    app.HazemapUIAxes.YLim = app.pixelModeYLim;
                    fprintf('Restored pixel mode zoom state: X[%.1f, %.1f], Y[%.1f, %.1f]\n', ...
                        app.pixelModeXLim(1), app.pixelModeXLim(2), app.pixelModeYLim(1), app.pixelModeYLim(2));
                        
                else
                    % No saved zoom state, use default full view
                    fprintf('No saved zoom state for current mode, using full view\n');
                end
                
            catch ME
                fprintf('Error restoring zoom state: %s\n', ME.message);
                % Fall back to full view on error
                axis(app.HazemapUIAxes, 'tight');
            end
        end
    end

    % Drawing methods (optimized versions)
    methods (Access = private)
        function canEnableMmMode = validateMmModeParameters(app)
            hasPixelSize = ~isempty(app.pixelSizeMm) && ~isnan(app.pixelSizeMm) && app.pixelSizeMm > 0;
            hasWaferSize = ~isempty(app.waferSizeMM) && ~isnan(app.waferSizeMM) && app.waferSizeMM > 0;
            hasImageLoaded = ~isempty(app.workingMap);
            
            canEnableMmMode = (hasPixelSize || hasWaferSize) && hasImageLoaded;
            
            if canEnableMmMode
                fprintf('MM mode can be enabled: PixelSize=%.4f, WaferSize=%.2f\n', ...
                        app.pixelSizeMm, app.waferSizeMM);
            else
                fprintf('MM mode not ready: hasPixelSize=%d, hasWaferSize=%d, hasImage=%d\n', ...
                        hasPixelSize, hasWaferSize, hasImageLoaded);
            end
        end

        function calculateMissingParameters(app)
            % Automatically calculate missing parameters based on image size and user input
            if isempty(app.workingMap)
                fprintf('No image loaded, cannot calculate parameters\n');
                return;
            end
            
            [~, imageWidth] = size(app.workingMap);
            
            hasPixelSize = ~isempty(app.pixelSizeMm) && ~isnan(app.pixelSizeMm) && app.pixelSizeMm > 0;
            hasWaferSize = ~isempty(app.waferSizeMM) && ~isnan(app.waferSizeMM) && app.waferSizeMM > 0;
            
            if hasPixelSize && hasWaferSize
                % Both available, prioritize Pixel Size and recalculate Wafer Size
                app.waferSizeMM = app.pixelSizeMm * imageWidth;
                app.WaferSizeEditField.Value = app.waferSizeMM;
                app.StatusLabel.Text = sprintf('Using Pixel Size priority: Wafer Size recalculated to %.2f mm', app.waferSizeMM);
                fprintf('Both parameters provided. Using Pixel Size priority: %.4f mm/pixel\n', app.pixelSizeMm);
                fprintf('Recalculated Wafer Size: %.2f mm (%.4f * %d pixels)\n', app.waferSizeMM, app.pixelSizeMm, imageWidth);
                
            elseif hasPixelSize && ~hasWaferSize
                % Only Pixel Size, calculate Wafer Size
                app.waferSizeMM = app.pixelSizeMm * imageWidth;
                app.WaferSizeEditField.Value = app.waferSizeMM;
                app.StatusLabel.Text = sprintf('Calculated Wafer Size: %.2f mm from Pixel Size %.4f mm', app.waferSizeMM, app.pixelSizeMm);
                fprintf('Calculated Wafer Size: %.2f mm (%.4f mm/pixel * %d pixels)\n', app.waferSizeMM, app.pixelSizeMm, imageWidth);
                
            elseif ~hasPixelSize && hasWaferSize
                % Only Wafer Size, calculate Pixel Size
                app.pixelSizeMm = app.waferSizeMM / imageWidth;
                app.PixelSizeEditField.Value = app.pixelSizeMm;
                app.StatusLabel.Text = sprintf('Calculated Pixel Size: %.4f mm from Wafer Size %.2f mm', app.pixelSizeMm, app.waferSizeMM);
                fprintf('Calculated Pixel Size: %.4f mm/pixel (%.2f mm / %d pixels)\n', app.pixelSizeMm, app.waferSizeMM, imageWidth);
                
            else
                % Neither available, cannot calculate
                app.StatusLabel.Text = 'Error: No size parameters provided. Please enter Pixel Size or Wafer Size.';
                fprintf('Error: No size parameters provided\n');
                return;
            end
            
            % After parameter calculation, enable Plot in mm checkbox
            app.PlotInMmCheckBox.Enable = 'on';
            fprintf('Plot in mm checkbox enabled after parameter calculation\n');
        end

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
            % Mouse button up for brush drawing (Modified version)
            if app.brushMode && app.IsDrawing
                app.IsDrawing = false;
                fprintf('\n*** Brush drawing completed ***\n');
                app.StatusLabel.Text = sprintf('Brush stroke completed on %s', app.currentLabel);
                
                % Clean up temporary brush overlays
                tempBrushes = findobj(app.HazemapUIAxes, 'Tag', 'TempBrush');
                delete(tempBrushes);
                
                % Now perform complete display update - don't restore zoom
                updateHazemapDisplay(app, false);
                updateAnnotationDisplay(app, false);
                
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

        function inArea = isMouseInImageArea(app)
            try
                pos = app.HazemapUIAxes.CurrentPoint;
                x = pos(1, 1);
                y = pos(1, 2);
                if app.bPlotInMm 
                    maxCoord = app.waferSizeMM / 2;
                    inMmBounds = (x >= -maxCoord && x <= maxCoord && y >= -maxCoord && y <= maxCoord);
                    xLimits = app.HazemapUIAxes.XLim;
                    yLimits = app.HazemapUIAxes.YLim;
                    inAxesView = (x >= xLimits(1) && x <= xLimits(2) && y >= yLimits(1) && y <= yLimits(2));
                    inArea = inMmBounds & inAxesView;
                else
                    [h, w] = size(app.workingMap);
                    inPixelBounds = (x >= 0 && x <= w && y >=0 && y <= h);
                    xLimits = app.HazemapUIAxes.XLim;
                    yLimits = app.HazemapUIAxes.YLim;
                    inAxesView = (x >= xLimits(1) && x <= xLimits(2) && y >= yLimits(1) && y <= yLimits(2));
                    inArea = inPixelBounds & inAxesView;
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

            % Convert coordinate to pixel
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
                    updateHazemapDisplay(app, false);
                    updateAnnotationDisplay(app, false);
                end
                
                fprintf('Drew at position (%.1f, %.1f) with %d pixels\n', x, y, sum(brushMask(:)));
            else
                fprintf('Position (%.1f, %.1f) outside image bounds\n', x, y);
            end
        end
        
        % Quick brush overlay
        function addBrushOverlayFast(app, x, y)
            % Add visual feedback at current mouse position quickly, without redrawing entire image
            try
                hold(app.HazemapUIAxes, 'on');
                
                % Get current label color
                if app.labelColors.isKey(app.currentLabel)
                    color = app.labelColors(app.currentLabel);
                else
                    color = [0.74 0.12 0.12]; % Default red color
                end

                if app.bPlotInMm
                    brushRadius = app.brushSize / 2 * app.pixelSizeMm;
                else
                    brushRadius = app.brushSize / 2;
                end 
                
                % Draw brush cursor
                theta = linspace(0, 2*pi, 50);
                brushX = x + brushRadius * cos(theta);
                brushY = y + brushRadius * sin(theta);
                
                % Temporarily show brush outline
                fill(app.HazemapUIAxes, brushX, brushY, color, 'EdgeColor','none', 'Tag', 'TempBrush');
                hold(app.HazemapUIAxes, 'off');
                
            catch ME
                fprintf('Error in fast overlay: %s\n', ME.message);
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
            % Generate polygon mask (Modified version)
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
                
                % Update displays - don't restore zoom
                updateHazemapDisplay(app, false);
                updateAnnotationDisplay(app, false);
                
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

    % Helper methods (Modified version)
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
                        
                        % Reset zoom state (new image should display full view)
                        app.pixelModeXLim = [];
                        app.pixelModeYLim = [];
                        app.mmModeXLim = [];
                        app.mmModeYLim = [];
                        app.hasPixelZoom = false;
                        app.hasMmZoom = false;
                        
                        updateDisplay(app, false); % New image doesn't need to restore zoom
                        app.CurrentFileLabel.Text = currentFile;
                        
                        % Reset annotation data for new image
                        app.annotationData = containers.Map();
                        keys = app.labelColors.keys;
                        for i = 1:length(keys)
                            app.annotationData(keys{i}) = false(size(app.originalMap));
                        end
                        
                        % Initialize combined mask
                        app.combinedMask = false(size(app.originalMap));
                        
                        % Initialize history and save initial state
                        app.annotationHistory = {};
                        app.historyIndex = 0;
                        saveToHistory(app);
                        
                        % Reset annotation modes and clear callbacks
                        app.brushMode = false;
                        app.polygonMode = false;
                        app.BrushModeButton.Value = false;
                        app.PolygonModeButton.Value = false;
                        app.cancelCurrentPolygon();
                        app.clearMouseCallbacks();
                        
                        % *** New: After image loading, check if mm mode can be enabled ***
                        if validateMmModeParameters(app) && app.PlotInMmCheckBox.Enable == "off"
                            calculateMissingParameters(app);
                        end
                        
                        fprintf('Image loaded: %s (size: %dx%d)\n', currentFile, size(app.originalMap,1), size(app.originalMap,2));
                        
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
        
        function updateDisplay(app, restoreZoom)
            % Unified display update method (Modified version)
            if nargin < 2
                restoreZoom = false;
            end
            
            if isempty(app.workingMap)
                return;
            end
            
            updateHazemapDisplay(app, restoreZoom);
            updateAnnotationDisplay(app, restoreZoom);
        end
        
        function updateHazemapDisplay(app, restoreZoom)
            % Modified version: Added restoreZoom parameter
            if nargin < 2
                restoreZoom = false;
            end
            
            if isempty(app.workingMap)
                return;
            end
            
            % Calculate coordinates
            [h, w] = size(app.workingMap);
            
            if app.bPlotInMm
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
            
            % Only restore zoom state when explicitly specified
            if restoreZoom
                restoreZoomState(app);
                fprintf('Zoom state restored due to coordinate system change\n');
            else
                fprintf('Hazemap updated without zoom restoration\n');
            end
            
            title(app.HazemapUIAxes, 'Hazemap with Annotations');
            
            % Update title with file info
            if ~isempty(app.CurrentFileLabel) && ~strcmp(app.CurrentFileLabel.Text, 'No file selected')
                title(app.HazemapUIAxes, sprintf('Hazemap: %s', app.CurrentFileLabel.Text));
            end
            
            fprintf('Hazemap display updated\n');
        end
        
        function updateAnnotationDisplay(app, restoreZoom)
            % Modified version: Added restoreZoom parameter to protect current zoom state
            if nargin < 2
                restoreZoom = false;
            end
            
            if isempty(app.workingMap)
                return;
            end
            
            % Save current zoom state (for annotation axes)
            currentXLim = [];
            currentYLim = [];
            hasCurrentZoom = false;
            
            % Only save current view when not needing to restore zoom
            if ~restoreZoom && ~isempty(app.annotationImageHandle) && isvalid(app.annotationImageHandle)
                try
                    currentXLim = app.AnnotationUIAxes.XLim;
                    currentYLim = app.AnnotationUIAxes.YLim;
                    hasCurrentZoom = true;
                catch
                    hasCurrentZoom = false;
                end
            end
            
            % Calculate coordinates
            [h, w] = size(app.workingMap);
            
            if app.bPlotInMm
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
            
            % Only set tight when restoreZoom=true or no current zoom
            if restoreZoom || ~hasCurrentZoom
                axis(app.AnnotationUIAxes, 'tight');
            end
            
            % Restore zoom state (but usually auto-synced by linkaxes, so this mainly prevents tight's effect)
            if ~restoreZoom && hasCurrentZoom && ~isempty(currentXLim) && ~isempty(currentYLim)
                try
                    app.AnnotationUIAxes.XLim = currentXLim;
                    app.AnnotationUIAxes.YLim = currentYLim;
                    fprintf('Current zoom state preserved for annotation display\n');
                catch
                    fprintf('Failed to restore current zoom state for annotation display\n');
                end
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
        
        % *** FIXED: Deep copy implementation for history ***
        function saveToHistory(app)
            % Trim history if needed
            if app.historyIndex < length(app.annotationHistory)
                app.annotationHistory = app.annotationHistory(1:app.historyIndex);
            end
            
            % Deep copy current annotation data
            currentStateCopy = containers.Map();
            if ~isempty(app.annotationData)
                keys = app.annotationData.keys;
                for i = 1:length(keys)
                    % Copy each label's mask data
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
