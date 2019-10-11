/*
The MIT License (MIT)
Copyright (c) 2014 Ismael Celis
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
-------------------------------*/
/*
Simplified WebSocket events dispatcher (no channels, no users)
var socket = new FancyWebSocket();
// bind to server events
socket.bind('some_event', function(data){
  alert(data.name + ' says: ' + data.message)
});
// broadcast events to all connected users
socket.send( 'some_event', {name: 'ismael', message : 'Hello world'} );
*/

// array buffer to string
function ab2str(buf) {
  return String.fromCharCode.apply(null, new Uint8Array(buf));
}

var TerminalEventsDispatcher = function(url) {
  var conn = new WebSocket(url);
  conn.binaryType = 'arraybuffer';

  var callbacks = {};

  this.bind = function(event_name, callback) {
    callbacks[event_name] = callbacks[event_name] || [];
    callbacks[event_name].push(callback);
    return this;// chainable
  };

  this.send = function(event_name, event_data) {
    var payload = JSON.stringify({event:event_name, data: event_data});
    conn.send( payload ); // <= send JSON data to socket server
    console.log("SEND: " + payload);
    return this;
  };

  this.send_binary = function(payload) {
    conn.send(payload); // <= send JSON data to socket server
    console.log("SEND_B: " + payload);
    return this;
  };

  // dispatch to the right handlers
  conn.onmessage = function(evt) {
    //console.log("RECV_WS: " + ab2str(evt.data));

    var msg = evt.data
    if (msg instanceof ArrayBuffer) {
      msg = ab2str(msg)
      msg = msg.substr("s:".length);
      
      var tid = msg.split(":")[0];
      msg = msg.substr("tid:".length);
      //console.log("MSG: " + msg);

      msg = msg.substr(29); // rest of data is binary msg (todo: make better)
      //console.log("MSG2: " + msg);


      console.log("dispatching stdout with tid: " + tid + " data: " +msg);
      dispatch("stdout", {tid: tid, msg: msg});
    } else {
      var json = JSON.parse(evt.data);
      console.log("RECV_TERM: " + evt.data);
      dispatch(json.event, json.data);
    }
  };

  var dispatch = function(event_name, message) {
    var chain = callbacks[event_name];
    if(typeof chain == 'undefined') return; // no callbacks for this event
    for(var i = 0; i < chain.length; i++){
      chain[i]( message )
    }
  }

  conn.onclose = function(){dispatch('close',null);}
  conn.onopen = function() {
    console.log("opened...");
    dispatch('open', null);
  }
};

var ApiEventsDispatcher = function(url) {
  var conn = new WebSocket(url);
  conn.binaryType = 'arraybuffer';

  var callbacks = {};

  this.bind = function(event_name, callback) {
    callbacks[event_name] = callbacks[event_name] || [];
    callbacks[event_name].push(callback);
    return this;// chainable
  };

  this.send = function(event_name, event_data) {
    var payload = JSON.stringify({event:event_name, data: event_data});
    conn.send( payload ); // <= send JSON data to socket server
    console.log("SEND_API: " + payload);
    return this;
  };

  // dispatch to the right handlers
  conn.onmessage = function(evt) {
    var json = JSON.parse(evt.data);
    console.log("RECV_API: " + evt.data);
    dispatch(json.event, json.data);
  };

  var dispatch = function(event_name, message) {
    var chain = callbacks[event_name];
    if(typeof chain == 'undefined') return; // no callbacks for this event
    for(var i = 0; i < chain.length; i++){
      chain[i]( message )
    }
  }

  conn.onclose = function(){dispatch('close',null);}
  conn.onopen = function() {
    console.log("opened...");
    dispatch('open', null);
  }
};