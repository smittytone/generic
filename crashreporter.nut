// Set up the crash reporter
// Code version for Squinter
#version "2.0.0"

/**
 * Generic development-oriented crash report service
 *
 * @author    Tony Smith (@smittytone)
 * @copyright Tony Smith, 2019
 * @licence   MIT
 * @version   2.0.0
 *
 */
crashReporter <- {

    /**
     * Reference to a function responsible for sending notifications
     *
     * @property
     *
     */
    "messenger" : null,

    "agentid": "",

    /**
     * Initilize the service
     *
     * @param {function} messengerFunction - The function to send error messages (agent only)
     *
     */
    "init" : function(reportStatus = false, messengerFunction = null) {
        // Register the agent's device message handler on the agent
        local isAgent = (imp.environment() == 2);

        // Set up the agent and check the messenger object
        if (isAgent) {
            if (messengerFunction == null || typeof messengerFunction != "function")
                throw("crashReporter.init() requires a messenger function");
            crashReporter.messenger = messengerFunction;
            device.on("crash.reporter.relay.debug.error", crashReporter.report);

            // FROM 2.0.0
            // Add device connection status reporting (disabled by default)
            if (reportStatus) {
                crashReporter.getagentid();

                device.onconnect(function() {
                    local report = "Agent " + agentid + " reports device " + imp.configparams.deviceid + " connected at " + crashReporter.timestamp();
                    crashReporter.messenger(report);
                }.bindenv(this));

                device.ondisconnect(function() {
                    local report = "Agent " + agentid + " reports device " + imp.configparams.deviceid + " registered as disconnected at " + crashReporter.timestamp();
                    crashReporter.messenger(report);
                }.bindenv(this));
            }
        }

        // Register the onunhandled callback
        imp.onunhandledexception(function(error) {
            // Only operate in DEBUG mode, ie. with development device groups
            if (__EI.DEVICEGROUP_TYPE == "development") {
                if (isAgent) {
                    // Running on the agent: just relay the error
                    crashReporter.report(error);
                } else {
                    // Running on the device: send the error to the agent
                    agent.send("crash.reporter.relay.debug.error", error);
                    server.flush(10);
                }
            }

            // Squirrel VM will restart at this point
        }.bindenv(this));
    },

    /**
     * Relay an error received from the device (or the agent itself)
     *
     * @param {string} error - The error message to relay
     *
     */
    "report" : function(error) {
        // Prepare the error report text
        local report = "*ERROR REPORT*\n*TIME* " + crashReporter.timestamp() + "\n";
        report += ("*ERROR* " + error + "\n");
        report += ("*DEVICE* " + imp.configparams.deviceid + "\n");
        report += ("*GROUP* " + __EI.DEVICEGROUP_NAME + "\n");
        report += ("*PRODUCT* " + __EI.PRODUCT_NAME);

        // Send the report text via the chosen messenger object
        crashReporter.messenger(report);
    },

    /**
     * Returns the current date as a formatted string
     *
     * @returns {string} The formatted date
     *
     */
    "timestamp": function() {
        local time = date();
        local bst = false;
        if ("utilities" in getroottable()) bst = utilities.isBST();
        time.hour += (bst ? 1 : 0);
        if (time.hour > 23) time.hour -= 24;
        local z = bst ? "+01:00" : "UTC";
        return format("%04d-%02d-%02d %02d:%02d:%02d %s", time.year, time.month + 1, time.day, time.hour, time.min, time.sec, z);
    },

    "getagentid": function() {
        local url = http.agenturl();
        local urlparts = split(url, "/");
        agentid = urlparts[2] + " of " + __EI.DEVICEGROUP_NAME + "/" + __EI.PRODUCT_NAME;
    }
};