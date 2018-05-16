// Provide disconnection functionality as a table of functions and properties
// Copyright Tony Smith, 2018
// Licence: MIT
// Code version 1.0.0
disconnectionManager <- {

    // Timeout periods
    "reconnectTimeout" : 30,
    "reconnectDelay" : 60,

    // Disconnection state data and information stores
    "monitoring" : false,
    "flag" : false,
    "message" : "",
    "reason" : SERVER_CONNECTED,
    "retries" : 0,
    "offtime" : null,

    // The event report callback
    // Should take the form 'function(event)', where 'event' is a table with the key 'message', whose
    // value is a human-readable string, and 'type' is a machine readable string, eg. 'connected'
    // NOTE 'type' may be absent for purely informational, event-less messages
    "eventCallback" : null,

    "eventHandler" : function(reason) {
        // Called if the server connection is broken or re-established
        // Sets 'flag' to true if there is NO connection
        if (!disconnectionManager.monitoring) return;
        if (reason != SERVER_CONNECTED) {
            // We weren't previously disconnected, so mark us as disconnected now
            if (!disconnectionManager.flag) {
                // Reset the disconnection data
                disconnectionManager.flag = true;
                disconnectionManager.retries = 0;
                disconnectionManager.reason = reason;

                // Record the disconnection time for future reference
                // NOTE connection fails 60s before eventHandler is called
                disconnectionManager.offtime = date();

                // Send a 'disconnected' event to the host app
                if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"message": "Device unexpectedly disconnected", "type" : "disconnected"});
            } else {
                // Send a 'still disconnected' event to the host app
                if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"type" : "disconnected"});
            }

            // Schedule an attempt to re-connect in 'reconnectDelay' seconds
            imp.wakeup(disconnectionManager.reconnectDelay, function() {
                if (!server.isconnected()) {
                    // If we're not connected, send a 'connecting' event to the host app and try to connect
                    disconnectionManager.retries += 1;
                    if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"message": "Device connecting", "type" : "connecting"});
                    server.connect(disconnectionManager.eventHandler.bindenv(this), disconnectionManager.reconnectTimeout);
                } else {
                    // If we are connected, re-call 'eventHandler()' to make sure the 'connnected' flow is executed
                    if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"message": "Wakeup code called, but already connected"});
                    disconnectionManager.eventHandler(SERVER_CONNECTED);
                }
            }.bindenv(this));
        } else {
            // The imp is back online
            if (disconnectionManager.flag && disconnectionManager.eventCallback != null) {
                // Send a 'connected' event to the host app
                local now = date();
                disconnectionManager.eventCallback({"message": format("Back online at %02i:%02i:%02i. Connection attempts: %i", now.hour, now.min, now.sec, disconnectionManager.retries), "type" : "connected"});

                // Report the time that the device went offline
                now = disconnectionManager.offtime;
                disconnectionManager.eventCallback({"message": format("Went offline at %02i:%02i:%02i. Reason %i", now.hour, now.min, now.sec, disconnectionManager.reason)});
            }

            disconnectionManager.flag = false;
            disconnectionManager.offtime = null;
        }
    }

    "start" : function() {
        // Register handlers etc.
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);
        server.onunexpecteddisconnect(disconnectionManager.eventHandler);
        disconnectionManager.monitoring = true;
        if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"message": "Enabling disconnection monitoring"});
    }

    "stop" : function() {
        // De-Register handlers etc.
        disconnectionManager.monitoring = false;
        if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"message": "Disabling disconnection monitoring"});
    }

    "connect" : function() {
        // Attempt to connect to the server if we're not connected already
        if (!server.isconnected()) {
            server.connect(disconnectionManager.eventHandler.bindenv(this), disconnectionManager.reconnectTimeout);
            if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"message": "Manually connecting to server", "type": "connecting"});
        } else {
            if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"type": "connected"});
        }
    }

    "disconnect" : function() {
        // Disconnect from the server if we're not disconnected already
        if (server.isconnected()) {
            server.flush(10);
            server.disconnect();
            if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"message": "Manually disconnected from server", "type": "disconnected"});
        } else {
            if (disconnectionManager.eventCallback != null) disconnectionManager.eventCallback({"type": "disconnected"});
        }
    }

    "setCallback" : function(cb = null) {
        // Convenience function for setting the framework's event report callback
        if (cb != null && typeof cb == "function") disconnectionManager.eventCallback = cb;
    }
}
