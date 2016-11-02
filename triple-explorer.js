// DONE: Translated to XQuery
if (!String.prototype.hashCode){
    String.prototype.hashCode = function() {
      var hash = 0, i, chr, len;
      if (this.length == 0) return hash;
      for (i = 0, len = this.length; i < len; i++) {
        chr   = this.charCodeAt(i);
        hash  = ((hash << 5) - hash) + chr;
        hash |= 0; // Convert to 32bit integer
      }
      return hash;
    };
};

// I've been spoiled by XQuery's fn:last() function...
if (!Array.prototype.last){
    Array.prototype.last = function(){
        return this[this.length - 1];
    };
};

var hashStringToHsvColor = function(string){
    if (typeof(string) == "string") {
        var hash = string.hashCode();
        return {
            h: (hash & 0xFF0000) >> 16,
            s: (hash & 0x00FF00) >> 8,
            v: (hash & 0x0000FF)
        };
    } else {
        return {
            h: 0,
            s: 0,
            v: 0
        };
    }; 
};

/** Accepts values from 0 to 1 */
var HSVtoRGB = function(h, s, v) {
    var r, g, b, i, f, p, q, t;
    if (h && s === undefined && v === undefined) {
        s = h.s, v = h.v, h = h.h;
    }
    i = Math.floor(h * 6);
    f = h * 6 - i;
    p = v * (1 - s);
    q = v * (1 - f * s);
    t = v * (1 - (1 - f) * s);
    switch (i % 6) {
        case 0: r = v, g = t, b = p; break;
        case 1: r = q, g = v, b = p; break;
        case 2: r = p, g = v, b = t; break;
        case 3: r = p, g = q, b = v; break;
        case 4: r = t, g = p, b = v; break;
        case 5: r = v, g = p, b = q; break;
    }
    return {
        r: Math.floor(r * 255),
        g: Math.floor(g * 255),
        b: Math.floor(b * 255)
    };
};

var string2color = function(string) {
    var hsv = hashStringToHsvColor(string);
    var rgb = HSVtoRGB(hsv.h/255, hsv.s/255, hsv.v/255);
    return "#" + rgb.r.toString(16) + rgb.g.toString(16) + rgb.b.toString(16);
};

var onSelect = function(properties) {
    
    // See if it was a node that was selected
    if (!properties.nodes) {
        alert('No nodes selected!');
        return;
    }

    if (properties.nodes.length == 1) {
        console.log(properties.nodes[0]);
        loadNode(properties.nodes[0]);

    } else {
        alert('Selected ' + properties.nodes.length + ' nodes.');
    }

};

var incoming=  {
    nodes: [],
    edges: []
};

var loadNode = function(nodeUri) {
    if (typeof(nodeUri) != "string") {
        console.log("loadNode called improperly!!!");
        console.log(nodeUri);
        return "input parameter of loadNode(nodeUri) is a string"
    } else {
        console.log("loadNode called with: " + nodeUri);

        $.ajax({
            type: "GET",
            url: "http://localhost:8005/v1/resources/tripleExplorer" 
            + "?rs:node=" + encodeURI(nodeUri)

        }).then(function(data) {
            
            console.log("loadNode callback!");
            var nodeData = data[0];
            var edgeData = data[1];
            nodes.clear();
            edges.clear();
            
            // Add incoming nodes
            for (n in nodeData) {
                if (n === "last") { n = nodeData.length - 1; }
                try {
                    nodes.add({
                        "id" : nodeData[n].id,
                        "label" : nodeData[n].label,
                        "color" : nodeData[n].color,
                        "shape" : nodeData[n].shape
                    });
                }
                catch(err) {
                    console.log('Duplicate node added.');
                }
                
            }
            
            // Add incoming edges
            for (e in edgeData) {
                if (e === "last") { e = edgeData.length - 1; }
                var edge = edgeData[e];
                var edgeName = (typeof(edge.color) == "string") ? (edge.color.split('"'))[1] : "";

                try {
                    edges.add({
                        "from"  : edge.from,
                        "to"    : edge.to,
                        "color" : string2color((typeof(edge.color) == "string") ? edge.color : "")
                    });
                }
                catch(err) {
                    console.log('Duplicate edge added.');
                }
                
            }
        });
    }
};
