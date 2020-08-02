#####
# File: SmartAnalyze.tcl
# Author: Hanlin Dong
# Create: 2019-06-28 10:42:19
# Version: 4.0.2 alpha
# Last update: 2020-06-11 19:58:00
# License: MIT License (https://opensource.org/licenses/MIT)
# (The latest version can be found on http://www.hanlindong.com/)
# Readme:
#     Introduction
#     ------------
#     The SmartAnalyze provides OpenSees users a easier way to conduct analyses.
#     There are two main functions defined in this .tcl file. SmartAnalyzeTransient & SmartAnalyzeStatic.
#     SmartAnalyzeTransient is used to conduct time history analyses.
#         The arguments must be specified are 
#             `dt`: delta t 
#             `npts`: number of points.
#     SmartAnalyzeStatic is used to conduct static analyze.
#         Users provide a loading protocol with displacement targets.
#         Then SmartAnalyze will run DisplacementControl analyses accordingly.
#         The arguments that must be specified are
#             `node`: the node tag in the displacement control
#             `dof`: the dof in the displacement control
#             `maxStep`: the maximum step length in the displacement control
#             `targets`: a list of target displacements. 
#                 (E.g. {1 -1 1 -1 0} will result in cyclic load of disp amplitude 1 twice.)
#                 Note: the first element must be positive.
#     If the control array is not specified, all the default values will be used.
#     If you want to change the control parameters, pass it as an array delegate.
#
#     Example
#     -------
#     Example 1: Basic usage for Transient
#         source SmartAnalyze.tcl
#         constraints Transformation
#         numberer Plain
#         system BandGeneral
#         integrator Newmark 0.5 0.25
#         SmartAnalyzeTransient $dt $npts
#
#     Example 2: Basic usage for Static 
#         source SmartAnalyze.tcl
#         constraints Transformation
#         numberer Plain
#         system BandGeneral
#         set protocol {1 -1 1 -1 0}
#         SmartAnalyzeStatic $node $dof $maxStep $protocol
#
#     Example 3: change control parameters
#         set control(printPer) 20
#         set control(tryAlterAlgoTypes) True
#         set control(algoTypes) {20 30}
#         SmartAnalyzeTransient $dt $npts control
#
#     Example 4: define user algorithm
#         proc UserAlgorithm0 {
#             algorithm KrylovNewton -increment initial -maxDim 10
#         }
#         set control(algoTypes) {80}
#         SmartAnalyzeTransient $dt $npts control
#
#     The work flow
#     -------------
#         1. Start
#         2. Set initial step length, algorithm method and test (You don't need to specify them in your model.)
#         3. Divide the whole analysis into pieces. For Static, use maxStep. For Transient, use dt.
#         4. Loop by each piece and analyze recursively with RecursiveAnalyze, in the following way
#             4.1 Trail analyze for one step, if converge, continue loop 4.
#             4.2 If not converge, if tryAddTestTimes is True, if the last test norm is smaller than normTol, recursively set a larger test time.
#             4.3 If not converge, if tryAlterAlgoTypes is True, recursively loop to the next algo type.
#             4.4 If not converge, divide the current step into two steps. The first one equals to the current step times relaxation.
#             4.5 If either step is smaller than minStep:
#                 4.5.1 If tryLooseTestTol is True, loose test tolerance to looseTestTolTo.
#                 4.5.2 Else, return not converge code. Exit.
#             4.6 If both steps are not smaller than minStep, divide the current piece into two and re-run loop 4.
#         5. If converge, return success message.
#
#     Control Parameters
#     ------------------
#     TEST RELATED:
#     `testType`        : string. Identical to the testType in OpenSees test command. Default is "EnergyIncr".
#                         Choices see http://opensees.berkeley.edu/wiki/index.php/Test_Command.
#     `testTol`         : float. The initial test tolerance set to the OpenSees test command. Default is 1.0e-6.
#                         If tryLooseTestTol is set to True, the test tolerance can be loosen.
#     `testIterTimes`   : integer. The initial number of test iteration times. Default is 7.
#                         If tryAddTestTimes is set to True, the number of test times can be enlarged.
#     `testPrintFlag`   : integer. The test print flag in OpenSees Test command. Default is 0.
#                         Choices see http://opensees.berkeley.edu/wiki/index.php/Test_Command.
#     `tryAddTestTimes` : boolean. Default is True If this is set to True, 
#                         the number of test times will be enlarged if the last test norm is smaller than `normTol`,
#                         the enlarged number is specified in `testIterTimesMore`.
#                         Otherwise, the number of test times will always be equal to `testIterTimes`.
#     `normTol`         : float. Only useful when tryAddTestTimes is True. Default is 1.0e3.
#                         If unconverge, the last norm of test will be compared to `normTol`.
#                         If the norm is smaller, the number of test times will be enlarged.
#     `testIterTimesMore` : integer. Only useful when tryaddTestTimes is True. Default is 50.
#                         If unconverge and norm is ok, the test iteration times will be set to this number.
#     `tryLooseTestTol` : boolean. If this is set to True, if unconverge at minimum step,
#                         the test tolerance will be loosen to the number specified by `looseTestTolTo`.
#                         the step will be set back.
#                         Default is True.
#     `looseTestTolTo`  : float. Only useful if tryLooseTestTol is True.
#                         If unconvergance at the min step, the test tolerance will be set to this value.
#                         Default is 1.
#     ALGORITHM RELATED:
#     `tryAlterAlgoTypes` : boolean. Default is False.
#                         If True, different algorithm types specified in `algoTypes` will be tried during unconvergance.
#                         If False, the first algorithm type specified in `algoTypes` will be used.
#     `algoTypes`       : list of integer. A list of flags of the algorithms to be used during unconvergance.
#                         The integer flag is documented in the following section.
#                         Only useful when tryAlterAlgoTypes is True. 
#                         The first flag will be used by default. 
#                         The algorithm command in the model will be ignored.
#                         Default is { 40 }
#                         If you need other algorithm, try a user-defined algorithm. See the following section.
#     STEP RELATED:
#     `initialStep`     : float. Default is equal to $dt.
#                         Specifying the initial Step length to conduct analysis.
#     `relaxation`      : float, between 0 and 1. Default is 0.5.
#                         A factor that is multiplied by each time the step length is shortened.
#     `minStep`         : float. Default is 1.0e-6.
#                         The step tolerance when shortening the step length.
#                         If step length is smaller than minStep, special ways to converge the model will be used according to `try-` flags.
#     LOGGING RELATED:
#     `printPer`        : integer. Print to the console every several trials. Default is 1.
#     `debugMode`       : boolean. Print as much information as possible.
#     DEPRECATED:
#     `tryForceConverge` : Using force converge will always give bad results.
#     `reorderAlgoTypes` : The algorithm types should not be reorded. 
#                        The script author should be responsible in providing the order.
#
#     Algorithm type flag reference
#     -----------------------------
#      0:  Linear
#      1:  Linear -initial
#      2:  Linear -factorOnce
#     10:  Newton
#     11:  Newton -initial
#     12:  Newton -initialThenCurrent
#     20:  NewtonLineSearch
#     21:  NewtonLineSearch -type Bisection
#     22:  NewtonLineSearch -type Secant
#     23:  NewtonLineSearch -type RegulaFalsi
#     30:  ModifiedNewton
#     31:  ModifiedNewton -initial
#     40:  KrylovNewton
#     41:  KrylovNewton -iterate initial
#     42:  KrylovNewton -increment initial
#     43:  KrylovNewton -iterate initial -increment initial
#     44:  KrylovNewton -maxDim 6
#     50:  SecantNewton
#     51:  SecantNewton -iterate initial
#     52:  SecantNewton -increment initial 
#     53:  SecantNewton -iterate initial -increment initial
#     60:  BFGS
#     70:  Broyden
#     80:  User-defined0
#     81:  User-defined1
#     82:  User-defined2
#     About User-defined algoType:
#         If special algorithm is to be used, SmartAyalize provides 3 user-defined algorithms.
#         The script author should specify the algorithm as a procedure in the script.
#         The script name must be `UserAlgorithm0`, `UserAlgorithm1`, `UserAlgorithm2`.
#         Example see section Example No. 4.
# Change Log:
#   2019-06-28 10:42:19 v0.0
#     Create file.
#   2019-06-28 18:04:52 v1.0
#     Created the main transient function SmartAnalyzeTransient
#   2019-07-03 12:27:06 v2.0
#     Created the main static fuction SmartAnalyzeStatic
#   2019-07-10 13:12:21 v2.1
#     Improve user interface and robustness
#   2019-07-12 16:11:26 v2.2
#     Add force converge report at the end of analysis
#   2020-03-31 00:48:57 v3.0
#     Add a parameter on whether reorder algoTypes on convergence.
#     Bug fix on finish percent.
#   2020-05-30 22:33:48 v4.0 alpha
#     Wholely refactor. Use mixed recurrance and recursive function.
#     Deprecate tryForceConverge and reorderAlgoTypes
#     Use array instead of dict to setup control parameters.
#     Reorganize documentation. Make code cleaner.
#   2020-06-01 10:22:28 v4.0.1 alpha
#     Bug fixes and output improvement.
#   2020-06-11 19:58:00 v4.0.2 alpha
#     Bug fix on setting default initialStep and return code.
#####

proc SmartAnalyzeTransient { dt npts {ud ""} } {
    # default control parameters
    set control(analysis)          "Transient"
    set control(testType)          "EnergyIncr"
    set control(testTol)           1.0e-6
    set control(testIterTimes)     7
    set control(testPrintFlag)     0
    set control(tryAddTestTimes)   True
    set control(normTol)           1.0e3
    set control(testIterTimesMore) 50
    set control(tryLooseTestTol)   True
    set control(looseTestTolTo)    1.
    set control(tryAlterAlgoTypes) False
    set control(algoTypes)         { 40 }
    set control(initialStep)       $dt
    set control(relaxation)        0.5
    set control(minStep)           1.0e-6
    set control(printPer)          10
    set control(debugMode)         False
    # set user control parameters
    if {$ud != ""} {
        upvar $ud userControl
        array set control [array get userControl]
    }
    puts "Control parameters:"
    puts [array get control]
    # initialize analyze commands
    test $control(testType) $control(testTol) $control(testIterTimes) $control(testPrintFlag)
    setAlgorithm [lindex $control(algoTypes) 0]
    analysis Transient
    # set an array to store current status.
    set current(startTime) [clock clicks -millisec]
    set current(algoIndex) 0
    set current(testIterTimes) $control(testIterTimes)
    set current(testTol) $control(testTol)
    set current(counter) 0
    set current(progress) 0
    set current(segs) $npts
    # divide the whole process into segments.
    for {set seg 1} {$seg <= $npts} {incr seg} {
        set ok [RecursiveAnalyze $control(initialStep) 0 $control(testIterTimes) $control(testTol) control current]
        if {$ok < 0} {
            puts ">>> SmartAnalyze: Analyze failed. Time consumption: [expr ([clock clicks -millisec]-$current(startTime)) / 1000.]s."
            return $ok
        }
        set current(progress) $seg
        if {$control(debugMode)} {
            puts "*** SmartAnalyze: progress $current(progress)/$current(segs)"
        }
    }
    puts ">>> SmartAnalyze: Successfully finished! Time consumption: [expr ([clock clicks -millisec]-$current(startTime)) / 1000.]s."
}

proc SmartAnalyzeStatic { node dof maxStep targets {ud ""} } {
    # set initial step
    if {$maxStep > [lindex $targets 0]} {
        set initialStep [lindex $targets 0]
    } else {
        set initialStep $maxStep
    }
    # default control parameters
    set control(analysis)          "Static"
    set control(testType)          "EnergyIncr"
    set control(testTol)           1.0e-6
    set control(testIterTimes)     7
    set control(testPrintFlag)     0
    set control(tryAddTestTimes)   True
    set control(normTol)           1.0e3
    set control(testIterTimesMore) 50
    set control(tryLooseTestTol)   True
    set control(looseTestTolTo)    1.
    set control(tryAlterAlgoTypes) False
    set control(algoTypes)         { 40 }
    set control(initialStep)       $initialStep
    set control(relaxation)        0.5
    set control(minStep)           1.0e-6
    set control(printPer)          10
    set control(debugMode)         False
    # set user control parameters
    if {$ud != ""} {
        upvar $ud userControl
        array set control [array get userControl]
    }
    puts "Control parameters:"
    puts [array get control]
    # initialize analyze commands
    test $control(testType) $control(testTol) $control(testIterTimes) $control(testPrintFlag)
    setAlgorithm [lindex $control(algoTypes) 0]
    integrator DisplacementControl $node $dof $initialStep
    analysis Static
    # set an array to store current status.
    set current(startTime) [clock clicks -millisec]
    set current(algoIndex) 0
    set current(testIterTimes) $control(testIterTimes)
    set current(testTol) $control(testTol)
    set current(counter) 0
    set current(progress) 0
    set current(step) $initialStep
    set current(node) $node
    set current(dof)  $dof
    # calcuate whole distance; divide the whole process into segments.
    set distance 0
    set segs [list ]
    for {set i 0} {$i < [llength $targets]} {incr i} {
        if {$i == 0} {
            set section [lindex $targets 0]
            set positive True
        } else {
            set section [expr [lindex $targets $i] - [lindex $targets $i-1]]
            if {$section >= 0} {
                set positive True
            } else {
                set positive False
            }
        }
        set distance [expr $distance + abs($section)]
        if {$positive} {
            for {set j 0} {[expr $section - $j*$maxStep] > $maxStep} {incr j} {
                lappend segs $maxStep
            }
            lappend segs [expr $section - [expr $j*$maxStep]]
        } else {
            for {set j 0} {[expr -$section - $j*$maxStep] > $maxStep} {incr j} {
                lappend segs [expr -$maxStep]
            }
            lappend segs [expr $section + [expr $j*$maxStep]]
        }
    }
    set current(segs) [llength $segs]
    # Run recursive analysis
    foreach seg $segs {
        set ok [RecursiveAnalyze $seg 0 $control(testIterTimes) $control(testTol) control current]
        if {$ok < 0} {
            puts ">>> SmartAnalyze: Analyze failed. Time consumption: [expr ([clock clicks -millisec]-$current(startTime)) / 1000.]s."
            return $ok
        }
        incr current(progress)
        if {$control(debugMode)} {
            puts "*** SmartAnalyze: progress $current(progress)/$current(segs)"
        }
    }
    puts ">>> SmartAnalyze: Successfully Finished! Time consumption: [expr ([clock clicks -millisec]-$current(startTime)) / 1000.]s."
}

proc RecursiveAnalyze {step algoIndex testIterTimes testTol vcontrol vcurrent} {
    upvar $vcontrol control $vcurrent current
    if {$control(debugMode)} {
        puts "*** SmartAnalyze: Run Recursive: step=$step, algoI=$algoIndex, times=$testIterTimes, tol=$testTol"
    }
    if {$algoIndex != $current(algoIndex)} {
        puts ">>> SmartAnalyze: Setting algorithm to [lindex $control(algoTypes) $algoIndex]"
        setAlgorithm [lindex $control(algoTypes) $algoIndex]
        set current(algoIndex) $algoIndex
    }
    if {$testIterTimes != $current(testIterTimes) || $testTol != $current(testTol)} {
        if {$testIterTimes != $current(testIterTimes)} {
            puts ">>> SmartAnalyze: Setting test iteration times to $testIterTimes"
            set current(testIterTimes) $testIterTimes
        } 
        if {$testTol != $current(testTol)} {
            puts ">>> SmartAnalyze: Setting test tolerance to $testTol"
            set current(testTol) $testTol
        }
        test $control(testType) $testTol $testIterTimes $control(testPrintFlag)
    }
    if {$control(analysis) == "Static" && $current(step) != $step} {
        puts ">>> SmartAnalyze: Setting step to $step"
        integrator DisplacementControl $current(node) $current(dof) $step
        set current(step) $step
    }
    # trial analyze once
    if {$control(analysis) == "Static"} {
        set ok [analyze 1]
    } else {
        set ok [analyze 1 $step]
    }
    set current(counter) [expr $current(counter) + 1]
    if {$ok == 0} {
        if {$current(counter) >= $control(printPer)} {
            puts "* SmartAnalyze: progress $current(progress)/$current(segs). Time consumption: [expr ([clock clicks -millisec]-$current(startTime)) / 1000.]s."
            set current(counter) 0
        }
        return 0
    } 
    # Add test iteration times. Use current step, algorithm and test tolerance.
    if {$control(tryAddTestTimes) && $testIterTimes != $control(testIterTimesMore)} {
        set norm [testNorms]
        if { [lindex $norm end] < $control(normTol) } {
            puts ">>> SmartAnalyze: Adding test times to $control(testIterTimesMore)."
            return [RecursiveAnalyze $step $algoIndex $control(testIterTimesMore) $testTol control current]
        } else {
            puts ">>> SmartAnalyze: Not adding test times for norm [lindex $norm end]."
        }
    }
    # Change algorithm. Set back test iteration times.
    if {$control(tryAlterAlgoTypes) && [incr algoIndex] < [llength $control(algoTypes)]} {
        puts ">>> SmartAnalyze: Setting algorithm to [lindex $control(algoTypes) $algoIndex]."
        return [RecursiveAnalyze $step $algoIndex $testIterTimes $testTol control current]
    }
    # If step length is too small, try add test tolerance. set algorithm and test iteration times back.
    if {[expr abs($step)] < [expr 2*$control(minStep)]} {
        puts ">>> SmartAnalyze: current step $step is too small!"
        if {$control(tryLooseTestTol) && $current(testTol) != $control(looseTestTolTo)} {
            puts "!!! SmartAnalyze: Warning: Loosing test tolerance  "
            return [RecursiveAnalyze $step 0 $control(testIterTimes) $control(looseTestTolTo) control current]
        }
        # Here, all methods have been tried. Return negative value.
        return -1
    }
    # Split the current step into two steps.
    set stepNew [expr $step * $control(relaxation)]
    if {$stepNew > 0 && $stepNew < $control(minStep)} {
        set stepNew $control(minStep)
    }
    if {$stepNew < 0 && $stepNew > [expr -$control(minStep)]} {
        set stepNew [expr -$control(minStep)]
    }
    set stepRest [expr $step - $stepNew]
    puts ">>> SmartAnalyze: Dividing the current step $step into $stepNew and $stepRest"
    set ok [RecursiveAnalyze $stepNew  0 $testIterTimes $testTol control current]
    if {$ok < 0} {
        return -1
    }
    set ok [RecursiveAnalyze $stepRest 0 $testIterTimes $testTol control current]
    if {$ok < 0} {
        return -1
    }
    return 1
}

proc setAlgorithm { type } {
    switch $type {
        0  {
            puts "> SmartAnalyze: Setting algorithm to  Linear ..."
            algorithm Linear
        }
        1  {
            puts "> SmartAnalyze: Setting algorithm to  -initial ..."
            algorithm -initial
        }
        2  {
            puts "> SmartAnalyze: Setting algorithm to  -factorOnce ..."
            algorithm -factorOnce
        }
        10 {
            puts "> SmartAnalyze: Setting algorithm to  Newton ..."
            algorithm Newton
        }
        11 {
            puts "> SmartAnalyze: Setting algorithm to  Newton -initial ..."
            algorithm Newton -initial
        }
        12 {
            puts "> SmartAnalyze: Setting algorithm to  Newton -initialThenCurrent ..."
            algorithm Newton -initialThenCurrent
        }
        20 {
            puts "> SmartAnalyze: Setting algorithm to  NewtonLineSearch ..."
            algorithm NewtonLineSearch
        }
        21 {
            puts "> SmartAnalyze: Setting algorithm to  NewtonLineSearch -type Bisection ..."
            algorithm NewtonLineSearch -type Bisection
        }
        22 {
            puts "> SmartAnalyze: Setting algorithm to  NewtonLineSearch -type Secant ..."
            algorithm NewtonLineSearch -type Secant
        }
        23 {
            puts "> SmartAnalyze: Setting algorithm to  NewtonLineSearch -type RegulaFalsi ..."
            algorithm NewtonLineSearch -type RegulaFalsi
        }
        30 {
            puts "> SmartAnalyze: Setting algorithm to  Modified Newton ..."
            algorithm Modified Newton
        }
        31 {
            puts "> SmartAnalyze: Setting algorithm to  ModifiedNewton -initial ..."
            algorithm ModifiedNewton -initial
        }
        40 {
            puts "> SmartAnalyze: Setting algorithm to  KrylovNewton ..."
            algorithm KrylovNewton
        }
        41 {
            puts "> SmartAnalyze: Setting algorithm to  KrylovNewton -iterate initial ..."
            algorithm KrylovNewton -iterate initial
        }
        42 {
            puts "> SmartAnalyze: Setting algorithm to  KrylovNewton -increment initial ..."
            algorithm KrylovNewton -increment initial
        }
        43 {
            puts "> SmartAnalyze: Setting algorithm to  KrylovNewton -iterate initial -increment initial ..."
            algorithm KrylovNewton -iterate initial -increment initial
        }
        44 {
            puts "> SmartAnalyze: Setting algorithm to  KrylovNewton -maxDim 50"
            algorithm KrylovNewton -maxDim 50
        }
        45 {
            puts "> SmartAnalyze: Setting algorithm to  KrylovNewton -iterate initial -increment initial -maxDim 50"
            algorithm KrylovNewton -iterate initial -increment initial -maxDim 50
        }
        50 {
            puts "> SmartAnalyze: Setting algorithm to  SecantNewton ..."
            algorithm SecantNewton
        }
        51 {
            puts "> SmartAnalyze: Setting algorithm to  SecantNewton -iterate initial ..."
            algorithm SecantNewton -iterate initial
        }
        52 {
            puts "> SmartAnalyze: Setting algorithm to  SecantNewton -increment initial  ..."
            algorithm SecantNewton -increment initial 
        }
        53 {
            puts "> SmartAnalyze: Setting algorithm to  SecantNewton -iterate initial -increment initial ..."
            algorithm SecantNewton -iterate initial -increment initial
        }
        60 {
            puts "> SmartAnalyze: Setting algorithm to  BFGS ..."
            algorithm BFGS
        }
        70 {
            puts "> SmartAnalyze: Setting algorithm to  Broyden ..."
            algorithm Broyden
        }
        80 {
            puts "> SmartAnalyze: Using user defined algorithm UserAlgorithm0."
            UserAlgorithm0
        }
        81 {
            puts "> SmartAnalyze: Using user defined algorithm UserAlgorithm1."
            UserAlgorithm1
        }
        82 {
            puts "> SmartAnalyze: Using user defined algorithm UserAlgorithm2."
            UserAlgorithm2
        }
        default {
            puts "!!! SmartAnalyze: ERROR! WRONG Algorithm Type!"
        }
    }
}


puts " ********************************************************************** "
puts " *                           WELCOME TO                               * "
puts " *  _____                      _    ___              _                * "
puts " * /  ___|                    | |  / _ \\            | |               * "
puts " * \\ `--. _ __ ___   __ _ _ __| |_/ /_\\ \\_ __   __ _| |_   _ _______  * "
puts " *  `--. \\ '_ ` _ \\ / _` | '__| __|  _  | '_ \\ / _` | | | | |_  / _ \\ * "
puts " * /\\__/ / | | | | | (_| | |  | |_| | | | | | | (_| | | |_| |/ /  __/ * "
puts " * \\____/|_| |_| |_|\\__,_|_|   \\__\\_| |_/_| |_|\\__,_|_|\\__, /___\\___| * "
puts " *                                                      __/ |         * "
puts " *                                                     |___/          * "
puts " * Author: Hanlin DONG (http://www.hanlindong.com)                    * "
puts " * License: MIT (https://opensource.org/licenses/MIT).                * "
puts " ********************************************************************** "

puts "Smart Analyze version 4.0.2 alpha loaded. Enjoy!"
puts "For transient analyze, call SmartAnalyzeTransient dt npts"
puts "For static analyze, call SmartAnalyzeStatic node dof targets maxStep"
puts " "
