; #Warn
#NoEnv
#Persistent
#SingleInstance force

#Include <Class_NvAPI>
#Include <NvidiaInspector>
#Include <GDIChart>
#Include <Debugging/JSON>

FinerCurves.Utilities.runAsAdmin()

class FinerCurves {
	
	class Model {		
		__New(_baseCoreClock, _baseMemoryClock) {
			if (!_baseCoreClock && !_baseMemoryClock) {
				MsgBox % "Missing GPU base clock values..."
			}
		
			this.coreClocks := new this.Clock("coreClocks", _baseCoreClock)
			this.memoryClocks := new this.Clock("memoryClocks", _baseMemoryClock)
		}
	
		class Clock {			
			__New(clockType, _baseClock) {
				this.baseClock := _baseClock
				this.type := clockType
				this.values[ this.type ] := {}
			}
			
			get(v*) {
				argCount := v.MaxIndex()
				return this[ "get" (argCount != "" ? argCount : 0)  ].(this, v*)
			}  
			
			get0() {
				return this.values[ this.type ]
			}
			
			get1(temperatureLimit) {
				return this.values[ this.type ][temperatureLimit]
			}
			
			set(perfState, temperatureLimit, clockValue) {
				this.values[ this.type ][temperatureLimit] := { perfState: perfState, clockValue: clockValue }
			}
		}
	}
	
	class View {
		__New(_baseCoreClock, _baseMemoryClock) {
			this.createFrame(640, 480)
			
			this.temperatureRange := 100
			this._baseCoreClock := _baseCoreClock
			this._baseMemoryClock := _baseMemoryClock
			this.scaleRatio := (this._baseCoreClock / this._baseMemoryClock)

			this.coreChartData := this.ChartData.create("line", this.temperatureRange, this._baseCoreClock)				
			this.memoryChartData := this.ChartData.create("line", this.temperatureRange, this._baseMemoryClock)
			
			this.updateChart()
		}
		
		bindWindowHooks() {
			OnMessage(0x200, ObjBindMethod(this, "OnMouseMove"))
			OnMessage(0x201, ObjBindMethod(this, "OnClick"))
		}
		
		CoordsToChartScreen(xPos, yPos, drawnChart) {
			windowMargins := drawnChart.Margin

			yn := Ceil(drawnChart.ygrid / (drawnChart.h // 36))
			
			x := (xPos - (windowMargins.left + 10)) // drawnChart.xratio
			y := (drawnChart.ycell * (drawnChart.ygrid // yn) * yn) - ((yPos - (windowMargins.top + 24 + 7)) // drawnChart.yratio)
			
			return { x: x, y: y }
		}
		
		OnMouseMove() {
			global gid
			CoordMode, Mouse, Client
			MouseGetPos, xPos, yPos, mouseFocusWndHwnd
			
			if (mouseFocusWndHwnd != gid) {
				Tooltip
				return
			}
			
			mousePositionInsideChart := this.CoordsToChartScreen(xPos, yPos, this.chart)
			Tooltip % JSON.Dump(mousePositionInsideChart)
		}
		
		OnClick() {
			CoordMode, Mouse, Client
			MouseGetPos, xPos, yPos
			
			mousePositionInsideChart := this.CoordsToChartScreen(xPos, yPos, this.chart)
			
			if (mousePositionInsideChart.x < 0 || mousePositionInsideChart.y < 0)
				return
			
			this.updateCharts(mousePositionInsideChart.x, mousePositionInsideChart.y, mousePositionInsideChart.y) ; TODO: Seperate chart controls...
		}
		
		createFrame(width := 640, height := 480) {
			Gui, +hwndgid +AlwaysOnTop +ToolWindow ;+E0x20
			Gui, Color, ffffff
			Gui, Add, Pic, w%width% h%height% Section Border 0xE hwndChartView
			Gui, Show,, Finer Curves GUI
			
			this.bindWindowHooks()
		}
	
		drawCharts(charts*) {
			global ChartView
			displayedChart := new GDIChart(ChartView)
			displayedChart.Grid(10, 13)
			
			for idx, chart in charts {
				displayedChart.drawData(chart.data, chart.color)
			}
			
			displayedChart.drawLabel()
			displayedChart.show()
			return displayedChart
		}
		
		redrawCharts() {
			this.chart := this.drawCharts({ data: this.coreChartData, color: 0xffff0000 }, { data: this.memoryChartData, color: 0xff0000ff })
		}
		
		updateChart(chart, x, y) {
			chart.add(x, y)
			this.redrawCharts()
			return this
		}
		
		updateCharts(temperatureLimit, coreClock, memoryClock) {
			this.coreChartData.add(temperatureLimit, coreClock * this.scaleRatio)
			this.memoryChartData.add(temperatureLimit, memoryClock)
			this.redrawCharts()
			return this
		}
	
		class ChartData {
			create(chartType := "line", xRangeLimit := 0, yRangeLimit := 0) {
				chartData := Object()
				chartData["chart"]:= chartType
				chartData["xmax"] := xRangeLimit
				chartData["ymax"] := yRangeLimit
				chartData["maxindex"] := 0
				chartData.base := this
				return chartData
			}
			
			add(x, y) {
				this["maxindex"]++
				this["x", this["maxindex"]] := x
				this["y", this["maxindex"]] := y
				return this
			}
			
			set(idx, x, y) {
				this["x", idx] := x
				this["y", idx] := y
				this["maxindex"] := idx
				return this
			}
		}
	}
	
	class Controller {		
		__New(_baseCoreClock := "", _baseMemoryClock := "") {
			this.gpuClocks := new FinerCurves.Model(_baseCoreClock, _baseMemoryClock)
						
			this.gpuMonitor := new this.MonitorGPU(this)
			this.activityMonitor := new FinerCurves.ActivityMonitor(this)

			; this.viewCharts := {} ; For testing purposes...
			this.viewCharts := new FinerCurves.View(_baseCoreClock, _baseMemoryClock)
		}
		
		fetchStats() {
			; TODO: Somehow read game application frames per second and take that into account of calculations?
			static gpuStats := {}
			
			; clocks := NvAPI.GPU_GetAllClockFrequencies()
			; loads := NvAPI.GPU_GetDynamicPstatesInfoEx()
					
			gpuStats.temperature := NvAPI.GPU_GetThermalSettings().1.currentTemp
			gpuStats.performanceState := NvAPI.GPU_GetCurrentPstate()
			; gpuStats.coreClock := Round(clocks.GRAPHICS.frequency / 1000, 0)
			; gpuStats.memoryClock := Round(clocks.MEMORY.frequency / 1000, 0)
			; gpuStats.GPULoad := loads.GPU.percentage
			; gpuStats.memoryLoad := loads.FB.percentage
			
			return gpuStats
		}
		
		calculateClock(clockType, currentTemp, clockData, currentPerfState := "P0") {
			closestToTargetIndexes := FinerCurves.Utilities.getClosestValues(currentTemp, clockData[clockType])
			
			closestCurvePoint := this.gpuClocks[clockType].get(closestToTargetIndexes.value)
			closestSecondCurvePoint := this.gpuClocks[clockType].get(closestToTargetIndexes.secondValue)
			
			offsetDirection := (currentTemp - closestToTargetIndexes.value) > 0 ? 1 : -1
			
			pointTempDistance := (closestToTargetIndexes.value - closestToTargetIndexes.secondValue) / 2
			
			modifiedClock := closestCurvePoint.clockValue + ((closestCurvePoint.clockValue - closestSecondCurvePoint.clockValue) * closestToTargetIndexes.dist) / pointTempDistance * offsetDirection
						
			if (!currentPerfState && closestCurvePoint.perfState == "P0" || currentPerfState == "P0") { ; TL,DR: "Maximum Performance" state takes an offsets instead of a raw numbers... 
				modifiedClock := modifiedClock - this.gpuClocks[clockType].baseClock
			}
			
			if (modifiedClock < (clockType == "coreClocks" ? -135 : -500)) { ; NVIDIA Inspector limits
				return this.calculateClock(clockType, currentTemp, clockData, "P1")
			}
						
			return { clockValue: modifiedClock, perfState: (!currentPerfState ? closestCurvePoint.perfState : currentPerfState) }
		}
		
		calculateClocksForTarget(currentTemp) {
			latestClocks := this.getClocks()

			modifiedCoreClock := this.calculateClock("coreClocks", currentTemp, latestClocks)
			modifiedMemoryClock := this.calculateClock("memoryClocks", currentTemp, latestClocks)
					
			if (modifiedCoreClock.perfState != modifiedMemoryClock.perfState) {
				if (modifiedCoreClock.perfState != "P0") {
					modifiedMemoryClock := this.calculateClock("memoryClocks", currentTemp, latestClocks, "P1")
				} else if (modifiedMemoryClock.perfState != "P0") {
					modifiedCoreClock := this.calculateClock("coreClocks", currentTemp, latestClocks, "P1")
				}
				modifiedPerfState := modifiedCoreClock.perfState
			}
			
			return { coreClock: modifiedCoreClock, memoryClock: modifiedMemoryClock, perfState: modifiedPerfState }
		}
		
		clockUpdator() {
			static lastActiveClocks := {}
			
			latestStats := this.fetchStats()
			
			currentTemp := latestStats.temperature
			if (currentTemp == "")
				return
				
			currentPerfState := "P" . latestStats.performanceState
		
			calculatedClocks := this.calculateClocksForTarget(currentTemp)
			
			modifiedCoreClock := calculatedClocks.coreClock.clockValue
			modifiedMemoryClock := calculatedClocks.memoryClock.clockValue
			
			if (lastActiveClocks.coreClock == modifiedCoreClock && lastActiveClocks.memoryClock == modifiedMemoryClock)
				return
		
			if (calculatedClocks.perfState != "" && currentPerfState != calculatedClocks.perfState) {
				InspectorAPI.setPerformanceState(calculatedClocks.perfState)
			}
			
			InspectorAPI.setGpuClock(modifiedCoreClock)
			InspectorAPI.setMemoryClock(modifiedMemoryClock)
			
			lastActiveClocks.coreClock := modifiedCoreClock
			lastActiveClocks.memoryClock := modifiedMemoryClock
		}
		
		toggleCoolingState(forceState := "") {
			static toggleActive, previousPerfState
			
			toggleActive := forceState != "" ? forceState : !toggleActive
			
			if (toggleActive) {
				previousPerfState := "P" . this.fetchStats().performanceState
				setState := "P5"
			} else {
				setState := previousPerfState
			}
			
			if (setState)
				InspectorAPI.setPerformanceState(setState)
		}
			
		getClocks() {		
			return {
			(Join,
				coreClocks: this.gpuClocks.coreClocks.get()
				memoryClocks: this.gpuClocks.memoryClocks.get()
			)}
		}
		
		setCurvePoint(perfState, temperatureLimit, clockValue, memoryClock) {
			this.gpuClocks.coreClocks.set(perfState, temperatureLimit, clockValue)
			this.gpuClocks.memoryClocks.set(perfState, temperatureLimit, memoryClock)
			this.viewCharts.updateCharts(temperatureLimit, clockValue, memoryClock)
			return this.gpuClocks
		}
		
		updateCurvePoint(clockType, perfState, temperatureLimit, clockValue) {
			this.gpuClocks[ clockType ].set(perfState, temperatureLimit, clockValue)
			return this.gpuClocks[ clockType ]
		}
		
		class MonitorGPU {
			static refreshInterval := 5 * 1000

			__New(parentInstance) {
				this.parent := parentInstance
				this.clockUpdator := ObjBindMethod(this.parent, "clockUpdator")
			}

			start() {
				FinerCurves.Utilities.setTimer(this.clockUpdator, this.refreshInterval)
			}
			
			stop() {
				this.parent.toggleCoolingState(false)
				FinerCurves.Utilities.setTimer(this.clockUpdator, "Off")
				Sleep, 1
				InspectorAPI.resetDefaults()
			}
		}
	}
	
	class ActivityMonitor {
		
		__Init() {		
			this.processes := [
			(Join,
				"ahk_exe cuisine_royale.exe"
				"ahk_exe starwarsjedifallenorder.exe"
			)]
		}
		
		__New(parentInstance) {
			this.parent := parentInstance
			
			this._hooks()
		}
		
		_hooks() {
			DllCall("RegisterShellHookWindow", UInt, A_ScriptHwnd)
			OnMessage(DllCall("RegisterWindowMessage", Str, "SHELLHOOK"), ObjBindMethod(this, "_shellMessage"))
		}
		
		__callback() {
			static lastState
			isActive := this._checkProcesses()
			
			if (!isActive && lastState) {
				this.parent.gpuMonitor.stop()
			}
			
			lastState := isActive
		}
		
		_shellMessage( wParam, lParam ) {
			if (wParam = 32772 || wParam = 4) {
				this.__callback()
			}
		}
		
		_checkProcesses() {
			for index, exeProcess in this.processes
				if (WinActive(exeProcess))
					return true
			return false
		}
	
	}
	
	class Tests {		
		__New(parentInstance) {
			this.parent := parentInstance
			
			; this.testApplyingClocks()
			this.projectCalculatedClocks()
			; this.projectCalculatedClocksForTarget(87)
		}
		
		testApplyingClocks() {
			currentTemp := 70
			calculatedClocks := this.parent.calculateClocksForTarget(currentTemp)
			InspectorAPI.setPerformanceState(calculatedClocks.perfState)
			InspectorAPI.setGpuClock(calculatedClocks.coreClock.clockValue)
			InspectorAPI.setMemoryClock(calculatedClocks.memoryClock.clockValue)
			MsgBox % JSON.Dump(calculatedClocks)
		}
		
		projectCalculatedClocks() {		
			tempTestResults := {}
			Loop % 100 {
				currentTemp := A_Index - 1
				if (currentTemp == "")
					return
							
				tempTestResults[ currentTemp ] := this.parent.calculateClocksForTarget(currentTemp)
			}
			NvAPI.HtmlBox(JSON.Dump(tempTestResults,, "`t"))
		}
		
		projectCalculatedClocksForTarget(targetTemp) {
			NvAPI.HtmlBox(JSON.Dump(this.parent.calculateClocksForTarget(targetTemp),, "`t"))
		}
	}
	
	class Utilities {
		getClosestValues(target, dataObject) {
			closestValues := { dist: 9999, value: "", secondValue: "" }
			for key, value in dataObject {
				distance := Abs(target - key)
				if (distance <= closestValues.dist) {
					closestValues.dist := distance 
					closestValues.secondValue := closestValues.value
					closestValues.value := key
				} else if (!closestValues.secondValue) {
					closestValues.secondValue := key
				}
			}
			return closestValues
		}
	
		runAsAdmin() {		
			FULL_COMMAND_LINE := DllCall("GetCommandLine", "str")
			if not (A_IsAdmin or RegExMatch(FULL_COMMAND_LINE, " /restart(?!\S)")) {
				try {
					if A_IsCompiled {
						Run *RunAs "%A_ScriptFullPath%" /restart	
					} else {
						Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
					}
				}
				ExitApp
			}
		}
		
		setTimer(fn, timer) {
			SetTimer, % fn, % timer
		}
	}
	
}

; InspectorAPI := {} ; for debugging - disable NVIDIA Inspector API

FinerCurves := new FinerCurves()
	
curveController := new FinerCurves.Controller(915, 2500)
curveController.setCurvePoint("P0", 90, 797 * (1 - 0.15), 2000)
curveController.setCurvePoint("P0", 85, 797, 2250)
curveController.setCurvePoint("P0", 65, 915, 2500)
curveController.setCurvePoint("P0", 50, 915, 2500)

; new FinerCurves.Tests(curveController)

^Space:: InspectorAPI.GPU_Assistant.cycleStates()
!Space:: curveController.toggleCoolingState()

!z:: curveController.gpuMonitor.start()
!x:: curveController.gpuMonitor.stop()
!y:: InspectorAPI.openGUI()

#If WinActive("ahk_exe notepad++.exe")
^R::Reload