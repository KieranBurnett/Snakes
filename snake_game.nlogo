;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     CMP2020-2324 Snake game                            ;;
;;                                                                        ;;
;; If you find any bugs or need help with Netlogo, contact the module     ;;
;;  delivery team (e.g. by posting a message on blackboard).              ;;
;;                                                                        ;;
;; This model was based on:                                               ;;
;;  Brooks, P. (2020) Snake-simple. Stuyvesant High School. Avaliable
;;  from http://bert.stuy.edu/pbrooks/fall2020/materials/intro-year-1/Snake-simple.html
;;    [accessed 16 November 2023].                                        ;;
;;                                                                        ;;
;; Don't forget to appropriately reference the resources you use!         ;;
;;                                                                        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  wall-color
  clear-colors ; list of colors that patches the snakes can enter have

  level tool ; ignore these two variables they are here to prevent warnings when loading the world/map.
]

patches-own [
  age ; if not part of a snake, age=-1. Otherwise age = ticks spent being a snake patch.
  path-cost ; used for path finding
  visited ; used in search methods
  parent ; used in search methods
]

breed [snakes snake]
snakes-own [
  team ; either red team or blue team
  mode ; how is the snake controlled.
  snake-age ; i.e., how long is the snake
  snake-color ; color of the patches that make up the snake
  planned_path
]

;;=======================================================
;; Setup

to setup ; observer
  clear-all
  setup-walls
  setup-snakes

  set clear-colors [black green]
  ; there will alwasy be two randomly placed pieces of food within the environment:
  make-food
  make-food
  reset-patches
  reset-ticks
end

;;--------------------------------

to setup-walls  ; observer
  ; none-wall patches are colored black:
  ask patches [ set age -1
                set pcolor black ]

  set wall-color gray

  ifelse map-file = "empty" [
    ; Set the edge of the environment to the wall-color:
    ask patches with [abs pxcor = max-pxcor or abs pycor = max-pycor] [set pcolor wall-color]
  ] [  ; load the map:
    let map_file_path (word "maps/" map-file ".csv")
    ifelse (file-exists? map_file_path) [
      import-world map_file_path
    ] [
      user-message "Cannot find map file. Please check the \"maps\" directory is in the same directory as this Netlogo model."
    ]
    ; set the patch size (so that the larger maps don't cover the controls)
    ifelse map-file = "snake-map-3" [ set-patch-size 11 ]
                                    [ set-patch-size 14 ]
  ]
end

to reset-patches
  ;; resest all patches to default values
  ask patches with [pcolor = black] [
      set path-cost 0
      set visited false
      set parent nobody ]
  ask patches with [pcolor = green] [
      set path-cost 0
      set visited false
      set parent nobody ]
end

;;--------------------------------

to setup-snakes  ; observer
  ; create the red/orange snake:
  create-snakes 1 [
    set team "red" ; /orange
    set xcor max-pxcor - 1
    set color red - 2
    set snake-color red + 11

    set mode red-team-mode
  ]
  ; create the blue/purple snake (but only when in two-player mode):
  if two-player[
    create-snakes 1 [
      set team "blue" ;/purple
      set xcor 0 -(max-pxcor - 1)
      set color blue - 2
      set snake-color blue + 11

      set mode blue-team-mode
    ]
  ]
  ; set the attributes that are the same for both snakes:
  ask snakes [
    set heading 0
    set ycor 0
    set snake-age 2 ; i.e. body contains two patches

    ;; Create the initial snake body
    ask patch [xcor] of self  0 [set pcolor [snake-color] of myself
                                 set age 0 ]
    ask patch [xcor] of self  -1 [set pcolor [snake-color] of myself
                                  set age 1]
    set planned_path (list )
  ]
end

;;=======================================================

;;;
; Make a random patch green (e.g. the color of the food)
to make-food
  ask n-of 1 patches with [pcolor = black] [
    set pcolor green]
end

to-report find-fruits ;; reports the 2 patches of "fruit"
  let fruits []
  ask patches with [pcolor = green] [
    set fruits lput self fruits
  ]
  report fruits
end

;;=======================================================

;;;
; Our main game control method
to go ; observer
  let loser nobody ; nobody has lost the game yet...
  let winner nobody ; nobody has won the game yet...

  ask snakes [
    ; 1. Set which direction the snake is facing:
    ;  You will want to expand the following if statement -- to call the approaches that you implement

    let opposing_colour (blue + 11)
    if snake-color = (blue + 11) [set opposing_colour (red + 11)]
    if (length planned_path = 0) or ([pcolor] of (first planned_path) = opposing_colour) or (not ([pcolor] of last planned_path = green)) [
    ;; if a new planned_path need to be generated, i.e. not human controlled
      ;; either because the fruit is no longer there
      ;; or because the snake is about to interact with the other snake
      ;; or because the snake has not yet searched for a fruit
      (ifelse
        mode = "human" []
        mode = "random" [random-neighboring-pathing]
        mode = "depth-first" [depth-first-pathing]
        mode = "breadth-first" [breadth-first-pathing]
        mode = "uniform" [uniform-pathing]
        mode = "greedy" [greedy-pathing]
        mode = "a*" [a*-pathing]) reset-patches]

    if not (mode = "human") [face first planned_path set planned_path remove-item (0) planned_path]

    ; 2. move the head of the snake forward
    fd 1

    ; 3. check for a collision (and thus game lost)
    if not member? pcolor clear-colors [
      set loser self
      stop
    ]

    ; 4. eat food
    if pcolor = green [
      make-food
      set snake-age snake-age + 1
      ask snakes [set planned_path (list )]
      ;; allows opposition snake to check if a fruit has appeared even closer than currently pathing to
    ]

    ; 5. check if max age reached (and thus game won)
    if snake-age >= max-snake-age [
      set winner self
      stop
    ]

    ; 6. move snake body parts forward
    ask patches with [pcolor = [snake-color] of myself] [
      set age age + 1
      if age > [snake-age] of myself [
        set age -1
        set pcolor black
      ]
    ]

    ; 7. set the patch colour and age of the snake's head.
    set pcolor snake-color
    set age 0
  ]

  ; A collision has happened: show message and stop the game
  (ifelse loser != nobody [
    user-message (word "Game Over! Team " [team] of loser " lost")
    stop
  ; A team has won: show message and stop the game
  ] winner != nobody [
    user-message (word "Game Over! Team " [team] of winner " won!")
    stop
  ])
  reset-patches
  tick

end

;;--------------------------------------------

;;;
; Make the turtle face a random unoccupied neighboring patch
;  if all patches are occupied, then any patch will be selected (and the snake lose :( )
to random-neighboring-pathing ; turtle
  let next-patch one-of neighbors4 with [member? pcolor clear-colors]

  if next-patch = nobody [ ; if none of the neighbours are clear:
    set next-patch one-of neighbors4
  ]
  ; make the snake face towards the patch we want the snake to go to:
  set planned_path (list next-patch)
end

to depth-first-pathing
  let fruits find-fruits
  let pathA depth-first-search patch-here first fruits
  let pathB depth-first-search patch-here last fruits
  let best_path []
  ifelse length pathA <= length pathB
    [set best_path pathA]
    [set best_path pathB]
  if smarter-pathing and two-player
  [
    ifelse self = snake 0 ;; if snake team red
    [ask snake 1
      [;; ask blue snake
        set best_path smart-path best_path pathA pathB (depth-first-search patch-here first fruits) (depth-first-search patch-here last fruits )
      ]
    ]
    [ ;; if snake team blue
      ask snake 0
      [;; ask red snake
        set best_path smart-path best_path pathA pathB (depth-first-search patch-here first fruits) (depth-first-search patch-here last fruits )
      ]
    ]
  ]
  if first best_path = patch-here [set best_path remove-item (0) best_path] ;; prevents first in the list being the current patch
  set planned_path best_path
end

to-report depth-first-search [start_location fruit]
  reset-patches
  if start_location = fruit [ report recover-plan fruit  ]
  let frontiers (list start_location)
  loop [
    if empty? frontiers [
      show "Failed to find a valid path."
      report (list one-of neighbors4 ) ]
    let node last frontiers
    set frontiers remove-item (length frontiers - 1) frontiers
    ask node [set visited true]
    foreach [valid-next-patches] of node [ valid_next_patch ->
      if (not ([visited] of valid_next_patch)) and (not member? valid_next_patch frontiers) [
        ask valid_next_patch [set parent node]
        if valid_next_patch = fruit [report recover-plan fruit ]
        set frontiers lput valid_next_patch frontiers
      ]
    ]
  ]
end

to breadth-first-pathing
  let fruits find-fruits
  let pathA breadth-first-search patch-here first fruits
  let pathB breadth-first-search patch-here last fruits
  let best_path []
  ifelse length pathA <= length pathB
    [set best_path pathA]
    [set best_path pathB]
  if smarter-pathing and two-player
  [
    ifelse self = snake 0 ;; if snake team red
    [ask snake 1
      [;; ask blue snake
        set best_path smart-path best_path pathA pathB (breadth-first-search patch-here first fruits) (breadth-first-search patch-here last fruits )
      ]
    ]
    [ ;; if snake team blue
      ask snake 0
      [;; ask red snake
        set best_path smart-path best_path pathA pathB (breadth-first-search patch-here first fruits) (breadth-first-search patch-here last fruits )
      ]
    ]
  ]
  if first best_path = patch-here [set best_path remove-item (0) best_path] ;; prevents first in the list being the current patch
  set planned_path best_path
end

to-report breadth-first-search [start_location fruit]
  reset-patches
  if start_location = fruit [ report recover-plan fruit  ]
  let frontiers (list start_location)
  loop [
    if empty? frontiers [
      show "Failed to find a valid path."
      report (list one-of neighbors4 ) ]
    let node last frontiers
    set frontiers remove-item (length frontiers - 1) frontiers
    ask node [set visited true]
    foreach [valid-next-patches] of node [ valid_next_patch ->
      if (not ([visited] of valid_next_patch)) and (not member? valid_next_patch frontiers) [
        ask valid_next_patch [set parent node]
        if valid_next_patch = fruit [report recover-plan fruit ]
        set frontiers fput valid_next_patch frontiers
      ]
    ]
  ]
end

to uniform-pathing
  let fruits find-fruits
  let pathA uniform-search patch-here first fruits
  let pathB uniform-search patch-here last fruits
  let best_path []
  ifelse length pathA <= length pathB
    [set best_path pathA]
    [set best_path pathB]
  if smarter-pathing and two-player
  [
    ifelse self = snake 0 ;; if snake team red
    [ask snake 1
      [;; ask blue snake
        set best_path smart-path best_path pathA pathB (uniform-search patch-here first fruits) (uniform-search patch-here last fruits )
      ]
    ]
    [ ;; if snake team blue
      ask snake 0
      [;; ask red snake
        set best_path smart-path best_path pathA pathB (uniform-search patch-here first fruits) (uniform-search patch-here last fruits )
      ]
    ]
  ]
  if first best_path = patch-here [set best_path remove-item (0) best_path] ;; prevents first in the list being the current patch
  set planned_path best_path
end

to-report uniform-search [start_location fruit]
  reset-patches
  if start_location = fruit [ report recover-plan fruit  ]
  ask start_location [set path-cost 0]
  let frontiers (list start_location)
  loop [
    if empty? frontiers [
      show "Failed to find a valid path."
      report (list one-of neighbors4 ) ]
    let node first frontiers
    set frontiers remove-item (0) frontiers
    ask node [set visited true]
    foreach [valid-next-patches] of node [ valid_next_patch ->
      if (not ([visited] of valid_next_patch)) and (not member? valid_next_patch frontiers) [
        ask valid_next_patch [set parent node set path-cost (([path-cost] of parent) + 1)]
        if valid_next_patch = fruit [report recover-plan fruit ]

        let temp false ;; inserting into correct spot in frontiers
        let curr_distance 0
        foreach frontiers [? ->
          if temp = false [
            if ([path-cost] of ? > [path-cost] of valid_next_patch) [
              set frontiers insert-item (position ? frontiers) frontiers valid_next_patch
              set temp true
            ]
          ]
        ]
        if temp = false [set frontiers lput valid_next_patch frontiers]
      ]
    ]
  ]
end

to greedy-pathing
  let fruits find-fruits
  let pathA greedy-search patch-here first fruits
  let pathB greedy-search patch-here last fruits
  let best_path []
  ifelse length pathA <= length pathB
    [set best_path pathA]
    [set best_path pathB]
  if smarter-pathing and two-player
  [
    ifelse self = snake 0 ;; if snake team red
    [ask snake 1
      [;; ask blue snake
        set best_path smart-path best_path pathA pathB (greedy-search patch-here first fruits) (greedy-search patch-here last fruits )
      ]
    ]
    [ ;; if snake team blue
      ask snake 0
      [;; ask red snake
        set best_path smart-path best_path pathA pathB (greedy-search patch-here first fruits) (greedy-search patch-here last fruits )
      ]
    ]
  ]
  if first best_path = patch-here [set best_path remove-item (0) best_path] ;; prevents first in the list being the current patch
  set planned_path best_path
end

to-report greedy-search [start_location fruit]
  reset-patches
  if start_location = fruit [ report recover-plan fruit  ]
  ask start_location [set path-cost distance fruit]
  let frontiers (list start_location)
  loop [
    if empty? frontiers [
      show "Failed to find a valid path."
      report (list one-of neighbors4 ) ]
    let node first frontiers
    set frontiers remove-item (0) frontiers
    ask node [set visited true]
    foreach [valid-next-patches] of node [ valid_next_patch ->
      if (not ([visited] of valid_next_patch)) and (not member? valid_next_patch frontiers) [
        ask valid_next_patch [set parent node set path-cost distance fruit]
        if valid_next_patch = fruit [report recover-plan fruit ]

        let temp false ;; inserting into correct spot in frontiers
        let curr_distance 0
        foreach frontiers [? ->
          if temp = false [
            ask ? [set curr_distance distance fruit]
            if (curr_distance >= [path-cost] of valid_next_patch) [
              set frontiers insert-item (position ? frontiers) frontiers valid_next_patch
              set temp true
            ]
          ]
        ]
        if temp = false [set frontiers lput valid_next_patch frontiers]
      ]
    ]
  ]
end

to a*-pathing
  let fruits find-fruits
  let pathA a*-search patch-here first fruits
  let pathB a*-search patch-here last fruits
  let best_path []
  ifelse length pathA <= length pathB
    [set best_path pathA]
    [set best_path pathB]
  if smarter-pathing and two-player
  [
    ifelse self = snake 0 ;; if snake team red
    [ask snake 1
      [;; ask blue snake
        set best_path smart-path best_path pathA pathB (a*-search patch-here first fruits) (a*-search patch-here last fruits )
      ]
    ]
    [ ;; if snake team blue
      ask snake 0
      [;; ask red snake
        set best_path smart-path best_path pathA pathB (a*-search patch-here first fruits) (a*-search patch-here last fruits )
      ]
    ]
  ]
  if first best_path = patch-here [set best_path remove-item (0) best_path] ;; prevents first in the list being the current patch
  set planned_path best_path
end

to-report a*-search [start_location fruit]
  reset-patches
  if start_location = fruit [ report recover-plan fruit  ]
  ask start_location [set path-cost 0]
  let frontiers (list start_location)
  loop [
    if empty? frontiers [
      show "Failed to find a valid path."
      report (list one-of neighbors4 ) ]
    let node first frontiers
    set frontiers remove-item (0) frontiers
    ask node [set visited true]
    foreach [valid-next-patches] of node [ valid_next_patch ->
      if (not ([visited] of valid_next_patch)) and (not member? valid_next_patch frontiers) [
        let distance_fruit 0
        ask valid_next_patch [set parent node set path-cost (([path-cost] of parent) + 1) set distance_fruit distance fruit]
        if valid_next_patch = fruit [report recover-plan fruit ]

        let temp false ;; inserting into correct spot in frontiers
        let curr_distance 0
        foreach frontiers [? ->
          let distance_fruit2 0
          if temp = false [
            ask ? [set distance_fruit2 distance fruit]
            if (([path-cost] of ?) + distance_fruit2 > ([path-cost] of valid_next_patch) + distance_fruit) [
              ;; adds path-cost to distance from fruit
              set frontiers insert-item (position ? frontiers) frontiers valid_next_patch
              set temp true
            ]
          ]
        ]
        if temp = false [set frontiers lput valid_next_patch frontiers]
      ]
    ]
  ]
end

to-report smart-path [best_path pathA pathB pathA-other pathB-other] ;; smarter-pathing option requires this, compares pathing
  ifelse (best_path = pathA) ;; if reds best path is to fruit 1, compare fruit 1 paths, else compare fruit 2 paths
    [ ;; if opposing snake would get the closest fruit first
      if length pathA-other < length pathA
      [ ;; check further fruit to see if closer to that one
        ifelse length pathB-other > length pathB [set best_path pathB] ;; if closer to further ruit swap path to that one
        [
          ifelse length pathA-other < length pathB-other ;; check to see which fruit opponent is closer to
          [set best_path pathB] ;; if opponent is closer to fruit1, path to fruit 2
          [set best_path pathA] ;; vice versa
        ]
      ]
    ]
    [
      if length pathB-other < length pathB ;; if reds best path is to fruit 1, compare fruit 1 paths, else compare fruit 2 paths
      [ ;; check further fruit to see if closer to that one
        ifelse length pathA-other > length pathA [set best_path pathA] ;; if closer to further ruit swap path to that one
        [
          ifelse length pathB-other < length pathA-other ;; check to see which fruit opponent is closer to
          [set best_path pathA] ;; if opponent is closer to fruit1, path to fruit 2
          [set best_path pathB] ;; vice versa
        ]
      ]
    ]
  report best_path
end
;;--------------------------------------------

to-report valid-next-patches ;; patch procedure
  let dirs []
  if member? ([pcolor] of patch-at 0 1) clear-colors
  [ set dirs lput patch-at 0 1 dirs ]
  if member? ([pcolor] of patch-at 1 0) clear-colors
  [ set dirs lput patch-at 1 0 dirs ]
  if member? ([pcolor] of patch-at 0 -1) clear-colors
  [ set dirs lput patch-at 0 -1 dirs ]
  if member? ([pcolor] of patch-at -1 0) clear-colors
  [ set dirs lput patch-at -1 0 dirs ]
  report dirs
end

to-report recover-plan [node ]
  let plan (list node)
  if [parent] of node = nobody [report (list node)]
  report recover-plan-recursive [parent] of node plan
end
;;;;;;
to-report recover-plan-recursive [node plan]
  set plan fput node plan
  if [parent] of node = nobody or [parent] of node = 0 [report plan]
  report recover-plan-recursive [parent] of node plan
end

;;---------------------
;; Human controlled snakes:
to head-up [selected-team]
  ask snakes with [team = selected-team] [ set heading 0 ]
end
;----
to head-right [selected-team]
  ask snakes with [team = selected-team] [ set heading 90 ]
end
;----
to head-down [selected-team]
  ask snakes with [team = selected-team] [ set heading 180 ]
end
;----
to head-left [selected-team]
  ask snakes with [team = selected-team] [ set heading 270 ]
end
;;---------------------

;;=======================================================

;; for displaying the age within the GUI:
to-report report-snake-age [team-name]
  report [snake-age] of one-of snakes with [team = team-name]
end

;;---------------------
@#$#@#$#@
GRAPHICS-WINDOW
210
10
669
470
-1
-1
11.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
36
37
109
70
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
36
74
99
107
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
477
486
615
531
red-team-mode
red-team-mode
"human" "random" "depth-first" "breadth-first" "uniform" "greedy" "a*"
6

BUTTON
251
537
306
570
up
head-up \"blue\"
NIL
1
T
OBSERVER
NIL
W
NIL
NIL
1

BUTTON
249
601
304
634
down
head-down \"blue\"
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
196
568
251
601
left
head-left \"blue\"
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
1

BUTTON
303
571
358
604
right
head-right \"blue\"
NIL
1
T
OBSERVER
NIL
D
NIL
NIL
1

CHOOSER
194
485
320
530
blue-team-mode
blue-team-mode
"human" "random" "depth-first" "breadth-first" "uniform" "greedy" "a*"
0

BUTTON
537
535
592
568
up
head-up \"red\"
NIL
1
T
OBSERVER
NIL
I
NIL
NIL
1

BUTTON
590
566
645
599
right
head-right \"red\"
NIL
1
T
OBSERVER
NIL
L
NIL
NIL
1

BUTTON
535
599
590
632
down
head-down \"red\"
NIL
1
T
OBSERVER
NIL
K
NIL
NIL
1

BUTTON
481
567
536
600
left
head-left \"red\"
NIL
1
T
OBSERVER
NIL
J
NIL
NIL
1

CHOOSER
34
135
181
180
map-file
map-file
"empty" "snake-map-1" "snake-map-2" "snake-map-3"
3

SWITCH
33
188
181
221
two-player
two-player
1
1
-1000

TEXTBOX
690
448
912
486
You need to press setup after changing the map or modes.
12
0.0
1

SLIDER
32
230
181
263
max-snake-age
max-snake-age
3
30
15.0
1
1
NIL
HORIZONTAL

MONITOR
324
486
399
531
Blue age
report-snake-age \"blue\"
0
1
11

MONITOR
619
487
690
532
Red age
report-snake-age \"red\"
0
1
11

SWITCH
732
38
876
71
smarter-pathing
smarter-pathing
0
1
-1000

TEXTBOX
718
80
925
192
On: Considers if opponent would get to the fruit first, tends to also prevent running into themselves\n\nOff: Paths to closest fruit to snake\n\n(has no effect on random pathing, human controlled or in single-player)
11
0.0
1

@#$#@#$#@
# CMP2020 -- Assessment Item 1

__If you find any bugs in the code or have any questions regarding the assessment, please contact the module delivery team.__

## Your details

Name: Kieran Burnett

Student Number: 26338680

## Extensions made

(a brief description of the extensions you have made -- that go beyond the search algorithms studied during this module.)

a smarter-pathing option that can change the outcome of a 2-player game 
It takes into account the opposing snakes location and path options
if the closeset fruit to the current snake is closer to the opposing snake it will instead check the other fruit
if the other fruit is closer to the current snake it will path to that one, if both are closer to the opponent it will just path to whichever is closest

the game also automatically recalculates routes for both snakes once a fruit has been "ate" to prevent snakes continuing to travel to fruit that is nolonger present





## References

(add your references below the provided reference)

Brooks, P. (2020) Snake-simple. Stuyvesant High School. Avaliable from http://bert.stuy.edu/pbrooks/fall2020/materials/intro-year-1/Snake-simple.html [accessed 16 November 2023].

code for pathing and pseudocode from workshops and lecture slides ->
Week B3 - w/c 12 Feb 2024 - Heuristic Search
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
