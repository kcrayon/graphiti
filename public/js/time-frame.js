Graphiti = window.Graphiti || {};

Graphiti.initTimeFramePicker = function(){
  var tf = Graphiti.getTimeFrame();
  if (tf) $("#time-frame option[value='" + tf + "']").attr('selected', 'selected');

  $("#time-frame").change(Graphiti.setTimeFrame);
};

Graphiti.getTimeFrame = function(){
  return localStorage.getItem("time-frame");
};
Graphiti.timeFrameOptions = function(){
  var tf = Graphiti.getTimeFrame()
  if (tf) {
    var ary = tf.split(",");
    return {"from": ary[0], "until": ary[1] };
  } else {
    return {};
  }
};

Graphiti.setTimeFrame = function(){
  localStorage.setItem("time-frame", $(this).val());
  location.reload();
};

$(Graphiti.initTimeFramePicker);
