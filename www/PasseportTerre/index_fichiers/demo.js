var examples = {};

examples['simple'] = function() {
  $('#sphere').earth3d({
    dragElement: $('#locations') // where do we catch the mouse drag
  });
};

examples['simple_tilted'] = function() {
  $('#sphere').earth3d({
    dragElement: $('#locations'), // where do we catch the mouse drag
    sphere: { // rotation and size of the planet
      tilt: 40,
      turn: 20,
      r: 10
    }
  });
};

examples['locations'] = function() {
  /* defining locations to display.
     Each position must have a key, an alpha and delta position (or x and y if you want to display a static location).
     Any additional key can be reached via callbacks functions.
  */
  var locations = {
    obj1: {
      alpha: Math.PI / 4,
      delta: 0,
      name: '_usa_',
      link: 'https://oasis.astroport.com#usa'
    },
    obj2: {
      alpha: 1 * Math.PI / 4,
      delta: -2 * Math.PI / 4,
      name: '_africa_',
      link: 'https://oasis.astroport.com#africa'
    },
    obj3: {
      alpha: 2 * Math.PI / 4,
      delta: 0,
      name: '_hawai_',
      link: 'https://oasis.astroport.com#awai'
    },
    obj4: {
      alpha: 3 * Math.PI / 4,
      delta: 3 * Math.PI / 4,
      name: '_australia_',
      link: 'https://oasis.astroport.com#australia'
    },
    obj5: {
      alpha: 2.2 * Math.PI / 4,
      delta: -0.9 * Math.PI / 4,
      name: '_southamerica_',
      link: 'https://oasis.astroport.com#southamerica'
    },
    obj6: {
      alpha: 1.2 * Math.PI / 4,
      delta: -2 * Math.PI / 4,
      name: '_europe_',
      link: 'https://oasis.astroport.com#europe'
    }
  };
  $('#sphere').earth3d({
    locationsElement: $('#locations'),
    dragElement: $('#locations'), // where do we catch the mouse drag
    locations: locations
  });
};

examples['flights'] = function() {
  /* defining locations to display.
     Each position must have a key, an alpha and delta position (or x and y if you want to display a static location).
     Any additional key can be reached via callbacks functions.
  */
  var locations = {
    obj1: {
      alpha: Math.PI / 4,
      delta: 0,
      name: '_usa_',
      link: 'https://oasis.astroport.com#usa'
    },
    obj2: {
      alpha: 1 * Math.PI / 4,
      delta: -2 * Math.PI / 4,
      name: '_africa_',
      link: 'https://oasis.astroport.com#africa'
    },
    obj3: {
      alpha: 2 * Math.PI / 4,
      delta: 0,
      name: '_hawai_',
      link: 'https://oasis.astroport.com#awai'
    },
    obj4: {
      alpha: 3 * Math.PI / 4,
      delta: 3 * Math.PI / 4,
      name: '_australia_',
      link: 'https://oasis.astroport.com#australia'
    },
    obj5: {
      alpha: 2.2 * Math.PI / 4,
      delta: -0.9 * Math.PI / 4,
      name: '_southamerica_',
      link: 'https://oasis.astroport.com#southamerica'
    },
    obj6: {
      alpha: 1.2 * Math.PI / 4,
      delta: -2 * Math.PI / 4,
      name: '_europe_',
      link: 'https://oasis.astroport.com#europe'
    },
    zero: {
      alpha: 0 * Math.PI / 4,
      delta: 0 * Math.PI / 4,
      name: '_CraftYourWorld_',
      link: 'https://ipfs.copylaradio.com/ipfs/QmNcNcYRDUFmR1Ey1MAyhzzZRJEi1Dfq8YXRTXq6XZ9n4A'
    },
    pi: {
      alpha: -3 * Math.PI / 4,
      delta: -3 * Math.PI / 4,
      name: '_OpenTW_',
      link: 'https://astroport.copylaradio.com'
    }
  };
  /* defining paths to display.
     Each path must have a key, an origin and a destination. The values are the location's key.
     You can, if you want to, define flights on these paths.
     Each flight has a key, a destination (the location's key) and a position.
     The position is the progress a fleet has made on its path.
     Any additional key can be reach via callbacks functions.
   */
  var paths = {
    path: {
      origin: 'obj1',
      destination: 'obj2',
      flights: {
        flight: {
          position: 0.25,
          destination: 'obj2',
          name: 'Flight 1'
        },
        flight2: {
          position: 0.25,
          destination: 'obj1',
          name: 'Flight 2'
        }
      }
    },
    path2: {
      origin: 'obj1',
      destination: 'obj3',
      flights: {
        flight3: {
          position: 0.5,
          destination: 'obj3',
          name: 'Flight 3'
        }
      }
    },
    path3: {
      origin: 'obj1',
      destination: 'obj4',
      flights: {
        flight4: {
          position: 0.5,
          destination: 'obj4',
          name: 'Flight 4'
        }
      }
    },
    path4: {
      origin: 'obj1',
      destination: 'obj5'
    },
    path7: {
      origin: 'obj1',
      destination: 'obj5',
      flights: {
        flight5: {
          position: 0.25,
          destination: 'obj7',
          name: 'Flight 5'
        }
      }
    }
  }

  $('#sphere').earth3d({
    flightsCanvas: $('#flights'),
    locationsElement: $('#locations'),
    dragElement: $('#locations'), // where do we catch the mouse drag
    paths: paths,
    locations: locations
  });
};

function selectExample(example) {
  $('#sphere').earth3d('destroy');
  $('#sphere').replaceWith($('<canvas id="sphere" width="400" height="400"></canvas>'));
  $('.location').remove();
  $('.flight').remove();
  $('#flights')[0].getContext('2d').clearRect(0, 0, 400, 400);
  if (example == 'simple_mars') {
    $('#glow-shadows').removeClass('earth').addClass('mars');
  } else {
    $('#glow-shadows').removeClass('mars').addClass('earth');
  }
  var code = examples[example].toString();
  code = code.substring(14);
  code = code.substring(0, code.length - 2);
  var lines = code.split("\n");
  for (var i = 0; i < lines.length; i++) {
    lines[i] = lines[i].substring(2);
  }
  code = lines.join("\n");
  $('#example_code').val(code);

  examples[example]();
}


$(document).ready(function() {
  selectExample('flights');

  $('#example').change(function() {
    selectExample($(this).val());
  });
});

function addPath() {
  $('#sphere').earth3d('changePaths', {path2: {
    origin: 'obj1',
    destination: 'obj3'
  }});
}
