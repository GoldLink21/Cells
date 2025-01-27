/**
 * Simple Js for node written to generate random 
 *   automata xml
 */



/** Random whole number from (0-n] @param {number} n */
function rand(n) {
    return Math.floor(Math.random() * n)
}

/**Random element of array or string */
function randElem(arr) {
    return arr[rand(arr.length)]
}

/**Generates a random string of 3 chars for 'random' naming */
function genName() {
    const key = "abcdefghijklmnopqrstuvwxyz"
    return randElem(key) + randElem(key) + randElem(key)
}

/**Generates a single hex color randomly */
function genColor() {
    const R = Math.floor(Math.random() * 256).toString(16).padStart(2, "0")
    const G = Math.floor(Math.random() * 256).toString(16).padStart(2, "0")
    const B = Math.floor(Math.random() * 256).toString(16).padStart(2, "0")
    return R + G + B
}

/**Generate N unique colors @param {number} n the number of colors */ 
function genColors(n) {
    let ret = [];
    for(let i = 0; i < n; i++) {
        let c = genColor()
        while(ret.includes(c)) c = genColor()
        ret.push(c)
    }
    return ret;
}

//////////////////////////////////

/**Generates N automatas in full XML format */
function genAutosXML(n) {
    let ret = 
        '<?xml version="1.1" standalone="no"?>\n' +
        // Uses xsd for verification
        '<autos xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' + 
            'xsi:noNamespaceSchemaLocation="autos.xsd">\n';

    for(let i = 0; i < n; i++) {
        ret += genAutoXML(i.toString())
    }
    return ret + '</autos>'
}

/**Generates a single automata in XML format */
function genAutoXML(name) {
    let nb = genNeighborhood()
    return  `    <auto name="${name}" neighborhood="${nb[0]}">` + "\n" +
                genStatesXML(nb[1], ) +
            "    </auto>\n"
}


/**
 * Generates a random weighted neighborhood and how many neighbors it can have
 * @returns {[string, number]} 
 */
function genNeighborhood() {
    const CHOICES = [
        // Weighted
        ["Moore",  8],["Moore",  8],["Moore",  8],["Moore",  8],["Moore",  8],
        ["Neuman", 8],["Neuman", 8],["Neuman", 8],["Neuman", 8],["Neuman", 8],
        ["Plus",   4],["Plus",   4],["Plus",   4],
        ["Diag",   4],["Diag",   4],
        ["BigX",   8],["BigX",   8],
        ["Hat",    3],
    ]
    return randElem(CHOICES)
}

/**
 * Generates a random number of states with a random number of transitions
 *  in XML based on number of max neighbors
 */
function genStatesXML(maxNeighbors) {
    // 2-6
    let numStates = rand(5) + 2
    let colors = genColors(numStates)
    let ret = ""
    for(let i = 0; i < numStates; i++) {
        let defaultState = i == 0 ? 0 : rand(numStates);
        ret += `        <state name="${i}" color="${colors[i]}" default="${defaultState}">` + "\n"
        let numTs = rand(4)
        // No Ts = reroll with less max
        if (numTs === 0) numTs = rand(2)
        
        for(let j = 0; j < numTs; j++) {
            ret += genTsXML(numStates, maxNeighbors, defaultState)
        }
        ret += "        </state>\n"
    }
    return ret
}

/**Generates a single random transition */
function genTsXML(numStates, maxNeighbors, defaultState) {
    let toState = rand(numStates)
    while (toState == defaultState) toState = rand(numStates)
    return `            <ts to="${toState}">${genRule(numStates, maxNeighbors)}</ts>` + "\n"
}

/**Generates N unique numbers of a max value */
function nUniq(n, max) {
    let nums = []
    for(let i = 0; i < n; i++) {
        let toAdd;
        do {
            toAdd = rand(max)
        } while (nums.includes(toAdd))
        nums.push(toAdd)
    }
    return nums
}

/**Generate a single random transition rule */
function genRule(numStates, maxNeighbors) {
    let ret = ""
    for(let i = 0; i < numStates; i++) {
        let chance = Math.random()
        if (chance < 0.4) {
            // Match any
            ret += "."
        } else if (chance < 0.75) {
            // Match a single count
            ret += rand(maxNeighbors)
        } else  {
            // Match a few counts
            ret += "[" + nUniq(rand(maxNeighbors - 1) + 1, maxNeighbors).sort().join("") + "]"
        } 
    }
    return ret
}

for(let i = 0; i < 5; i++) {
    console.log(genAutoXML(genName()))
}