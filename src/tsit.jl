# Butcher Tableau
const B = [[0.161],
        [-0.008480655492356992, 0.3354806554923570],
        [2.8971530571054944, -6.359448489975075, 4.362295432869581],
        [5.32586482843926, -11.74888356406283, 7.495539342889836, -0.09249506636175525],
        [5.86145544294642, -12.92096931784711, 8.159367898576159,  -0.07158497328140100,
        -0.02826905039406838],
        [0.09646076681806523, 0.01, 0.4798896504144996, 1.379008574103742,
        -3.290069515436081, 2.324710524099774]
        ]

# Step size fractions
const nodes = [0.161, 0.327, 0.9, 0.9800255409045097, 1, 1]

# Weights for 5th order method
const b5 = [0.001780011052226, 0.000816434459657, -0.007880878010262, 0.144711007173263,         
            -0.582357165452555, 0.458082105929187, 1/66]
# Weights for 4th order method
const b4 = [0.09646076681806523, 0.01, 0.4798896504144996, 1.379008574103742,
                -3.290069515436081, 2.324710524099774, 0]
# Error estimate
const errest = b5 .- b4

#Interpolation coefficients
const interpC = hcat(
    [1.0, -2.763706197274826, 2.9132554618219126, -1.0530884977290216],
    [0, 0.13169999999999998, -0.2234, 0.1017],
    [0, 3.9302962368947516, -5.941033872131505, 2.490627285651253],
    [0, -12.411077166933676, 30.33818863028232, -16.548102889244902],
    [0, 37.50931341651104, -88.1789048947664, 47.37952196281928],
    [0, -27.896526289197286, 65.09189467479366, -34.87065786149661],
    [0, 1.5, -4, 2.5]
)