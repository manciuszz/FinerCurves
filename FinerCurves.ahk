#NoEnv
#SingleInstance Force

#Include <Class_NvAPI>
#Include <NvidiaInspector>
#Include <Debugging/JSON>
 
AutoGPU.Utilities.runAsAdmin()

class FinerCurves {	
	static gpuStats := {}
	static gpuCurve := {}
	
	__New() {	
		this.refreshInterval := 5 * 1000
	
		this._gpuActiveClocks := { coreClock: "", memoryClock: "" }
		this.gpuBaseClocks := { coreClock: 915, memoryClock: 2500 } ; These are "GPU Boost" clocks
	
		; TODO: Write a GUI for setting curve points...
		; Note: Adjust clocks if experiencing game crashes, artifacts or instability in general...
		this.setCurvePoint(90, "P0", 797 * (1 - 0.10), 2000)
		this.setCurvePoint(85, "P0", 797, 2250)
		this.setCurvePoint(75, "P0", 915, 2500)
		this.setCurvePoint(70, "P0", 915, 2500)
		
		this.refreshFn_ref := ObjBindMethod(this, "refreshedFn")
		
		new this.ActivityMonitor(this)
		
		; new this.Tests(this)
		
		; this.start()
	}
	
	setCurvePoint(temperatureLimit, performanceState, coreClock := "", memoryClock := "") {
		this.gpuCurve[temperatureLimit] := { perfState: performanceState, coreClock: coreClock, memoryClock: memoryClock }
	}
	
	updateStats() {
		; TODO: Check for specific processes?
		; TODO: Somehow read game application frames per second and take that into account of calculations?
		
		clocks := NvAPI.GPU_GetAllClockFrequencies()
		loads := NvAPI.GPU_GetDynamicPstatesInfoEx()
				
		this.gpuStats.temperature := NvAPI.GPU_GetThermalSettings().1.currentTemp
		this.gpuStats.performanceState := NvAPI.GPU_GetCurrentPstate()
		this.gpuStats.coreClock := Round(clocks.GRAPHICS.frequency / 1000, 0)
		this.gpuStats.memoryClock := Round(clocks.MEMORY.frequency / 1000, 0)
		this.gpuStats.GPULoad := loads.GPU.percentage
		this.gpuStats.memoryLoad := loads.FB.percentage
	}
	
	calculateClocks(currentTemp, currentPerfState := "") {
		closestTemps := this.Utilities.getClosestValues(currentTemp, this.gpuCurve)
				
		closestCurvePoint := this.gpuCurve[closestTemps.value]
		closestSecondCurvePoint := this.gpuCurve[closestTemps.secondValue]
		
		offsetDirection := (currentTemp - closestTemps.value) > 0 ? 1 : -1
			
		modifiedCoreClock := closestCurvePoint.coreClock + ((closestCurvePoint.coreClock - closestSecondCurvePoint.coreClock) * closestTemps.dist) / (closestTemps.value - closestTemps.secondValue) * offsetDirection
		modifiedMemoryClock := closestCurvePoint.memoryClock + ((closestCurvePoint.memoryClock - closestSecondCurvePoint.memoryClock) * closestTemps.dist) / (closestTemps.value - closestTemps.secondValue) * offsetDirection
			
		if (!currentPerfState && closestCurvePoint.perfState == "P0" || currentPerfState == "P0") { ; TL,DR: "Maximum Performance" state takes an offsets instead of a raw numbers... 
			modifiedCoreClock := modifiedCoreClock - this.gpuBaseClocks.coreClock
			modifiedMemoryClock := modifiedMemoryClock - this.gpuBaseClocks.memoryClock
		}
		
		if (modifiedCoreClock < -135 || modifiedMemoryClock < -500) {
			return this.calculateClocks(currentTemp, "P1")
		}	
		
		return { coreClock: modifiedCoreClock, memoryClock: modifiedMemoryClock, perfState: (!currentPerfState ? closestCurvePoint.perfState : currentPerfState) }
	}
	
	refreshedFn() {
		this.updateStats()
		
		; currentLoad := this.gpuStats.GPULoad
		currentPerfState := "P" . this.gpuStats.performanceState
		currentTemp := this.gpuStats.temperature
		if (currentTemp == "")
			return
		
		calculatedClocks := this.calculateClocks(currentTemp, currentPerfState)

		if (this._gpuActiveClocks.coreClock == calculatedClocks.coreClock && this._gpuActiveClocks.memoryClock == calculatedClocks.memoryClock) { ; Don't try to overclock to the same values...
			return
		}
		
		; TODO: Take into account GPU Loads... (Pro Tip: Low GPU load doesn't really need higher clocks)
		
		if (currentPerfState != calculatedClocks.perfState) {
			InspectorAPI.setPerformanceState(calculatedClocks.perfState)
		}

		InspectorAPI.setGpuClock(calculatedClocks.coreClock)
		InspectorAPI.setMemoryClock(calculatedClocks.memoryClock)
		
		this._gpuActiveClocks.coreClock := calculatedClocks.coreClock
		this._gpuActiveClocks.memoryClock := calculatedClocks.memoryClock
	}
	
	start() {
		this.Utilities.setTimer(this.refreshFn_ref, this.refreshInterval)
	}
	
	stop() {
		this.Utilities.setTimer(this.refreshFn_ref, "Off")
		InspectorAPI.resetDefaults()
	}
	
	class ActivityMonitor {
		
		__Init() {		
			this.processes := [
			(Join,
				"ahk_exe cuisine_royale.exe"
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
				this.parent.stop()
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
		}
		
		testApplyingClocks() {
			currentTemp := 85
			calculatedClocks := this.parent.calculateClocks(currentTemp)
			InspectorAPI.setPerformanceState(calculatedClocks.perfState)
			InspectorAPI.setGpuClock(calculatedClocks.coreClock)
			InspectorAPI.setMemoryClock(calculatedClocks.memoryClock)
			MsgBox % JSON.Dump(calculatedClocks)
		}
		
		projectCalculatedClocks() {
			; this.updateStats()
		
			tempTestResults := {}
			Loop % 100 {
				currentTemp := A_Index - 1
				if (currentTemp == "")
					return
			
				calculatedClocks := this.parent.calculateClocks(currentTemp)
				
				tempTestResults[ currentTemp ] := [calculatedClocks.perfState, calculatedClocks.coreClock, calculatedClocks.memoryClock]
			}
			NvAPI.HtmlBox(JSON.Dump(tempTestResults,, "`t"))
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

FinerCurves := new FinerCurves()

!z:: FinerCurves.start()
!x:: FinerCurves.stop()
!y:: InspectorAPI.openGUI()

#If WinActive("ahk_exe notepad++.exe")
^R:: Reload