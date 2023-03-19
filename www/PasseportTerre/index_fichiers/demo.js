function selectExample(example) {
  $('#sphere').earth3d('destroy');
  $('#sphere').replaceWith($('<canvas id="sphere" width="400" height="400"></canvas>'));
  $('.location').remove();
  //~ $('.flight').remove();
  //~ $('#flights')[0].getContext('2d').clearRect(0, 0, 400, 400);
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
  selectExample('locations');

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
