class InspectorAPI { ; Requires Administrator privileges...
	static perfState := -1

	static inspectorPath := A_ScriptDir . "\Tools\nvidiaInspector.exe"

	openGUI() {
		Run % this.inspectorPath
	}

	cli(command := "") {
		static commandBuffer := ""
		static debouncerInterval := 1
		static self := ObjBindMethod(InspectorAPI, "cli", true)
		
		if (!command)
			return
			
		if (command == true) {
			Run % this.inspectorPath . " " . commandBuffer,, Hide
			commandBuffer := ""
			Sleep, % debouncerInterval
		} else {
			commandBuffer .= command . " "
			SetTimer, % self, % -debouncerInterval
		}
		
	}
	
	resetDefaults(gpuID := 0) {
		this.restorePStates(gpuID)
		this.setPerformanceState()
		this.Clocks.reset()
		this.Clocks.Offset.reset()
		this.GPU_Assistant.perfIndex := 1
	}
	
	restorePStates(gpuID := 0) {
		this.cli("-restoreAllPStates:" . gpuID)
	}
	
	getPerformanceState() {
		if (this.perfState == -1)
			this.setPerformanceState()
		return this.perfState
	}

	setPerformanceState(pState := "P0", gpuID := 0) {
		static performanceStatesMap := { "P0": 0, "P1": 1, "P5": 5, "P8": 8,   0:0, 1:1, 5:5, 8:8 }	
		; MsgBox % "-setPStateLimit:" . gpuID . "," . performanceStatesMap[pState]
		; return
		
		this.cli("-setPStateLimit:" . gpuID . "," . performanceStatesMap[pState])
		this.perfState := performanceStatesMap[pState]
	}
	
	setGpuClock(clockIncrement := 1, applyInstead := true, pState := "P1", gpuID := 0) {
		static performanceStatesMap := { "P1": 2, "P5": 1, "P8": 0,   0:0, 2:2, 1:1 }
		clockIncrement := Format("{:d}", clockIncrement)
		
		; MsgBox % "-setGpuClock:" . gpuID . "," . performanceStatesMap[pState] . "," . clockIncrement
		; return
		
		if (this.getPerformanceState() == 0)
			return this.setBaseClockOffset(clockIncrement, applyInstead, gpuID)
		
		if (applyInstead)
			return this.cli("-setGpuClock:" . gpuID . "," . performanceStatesMap[pState] . "," . clockIncrement)
		
		this.cli("-setGpuClock:" . gpuID . "," . performanceStatesMap[pState] . "," . (this.Clocks.Core := this.Clocks.Core + clockIncrement))
	}
	
	setBaseClockOffset(clockIncrement := 1, applyInstead := true, gpuID := 0) {		
		if (applyInstead)
			return this.cli("-setBaseClockOffset:" . gpuID . "," . 0 . "," . clockIncrement)
		
		this.cli("-setBaseClockOffset:" . gpuID . "," . 0 . "," . (this.Clocks.Offset.Core := this.Clocks.Offset.Core + clockIncrement))
	}
	
	setMemoryClock(clockIncrement := 1, applyInstead := true, pState := "P1", gpuID := 0) {
		static performanceStatesMap := { "P1": 2, "P5": 1, "P8": 0,   0:0, 2:2, 1:1 }
		clockIncrement := Format("{:d}", clockIncrement)
		
		; MsgBox % "-setMemoryClock:" . gpuID . "," . performanceStatesMap[pState] . "," . clockIncrement
		; return
		
		if (this.getPerformanceState() == 0)
			return this.setMemoryClockOffset(clockIncrement, applyInstead, gpuID)
		
		if (applyInstead)
			return this.cli("-setMemoryClock:" . gpuID . "," . performanceStatesMap[pState] . "," . clockIncrement)
		
		this.cli("-setMemoryClock:" . gpuID . "," . performanceStatesMap[pState] . "," . (this.Clocks.Memory := this.Clocks.Memory + clockIncrement))
	}
	
	setMemoryClockOffset(clockIncrement := 1, applyInstead := true, gpuID := 0) {		
		if (applyInstead)
			return this.cli("-setMemoryClockOffset:" . gpuID . "," . 0 . "," . clockIncrement)
		
		this.cli("-setMemoryClockOffset:" . gpuID . "," . 0 . "," . (this.Clocks.Offset.Memory := this.Clocks.Offset.Memory + clockIncrement))
	}
	
	class Clocks {
		static Offset := new InspectorAPI.Clocks(0, 0)
		static _ := InspectorAPI.Clocks := new InspectorAPI.Clocks(797, 2000)
		
		__New(coreValue, memoryValue) {
			this.set(coreValue, memoryValue)
		
			this.reset := this.set.Bind(this, coreValue, memoryValue)
		}
		
		set(coreValue, memoryValue) {
			this.Core := coreValue
			this.Memory := memoryValue
		}
	}
		
	class GPU_Assistant {
		static perfIndex := 1

		cycleStates() {
			static perfStates := [1,5,8,0]
			
			InspectorAPI.setPerformanceState(perfStates[this.perfIndex])
			this.perfIndex := Mod(this.perfIndex, perfStates.Length()) + 1
		}
		
	}
}