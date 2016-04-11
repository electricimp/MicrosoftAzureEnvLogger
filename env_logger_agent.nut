#require "azureiothub.class.nut:1.1.0"

//
// Environmental Logger Demo integrated with Azure IoT Hub
// Agent
//

// *****************************************************************************
const CONNECT_STRING = "HostName=imptesthuba.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=";
client <- null;

// This bootstraps the IoT Hub class by getting the deviceInfo or registering a new device.
// If successful it will return a IoTHub client object.
function connect() {
    
    local registry = iothub.Registry.fromConnectionString(CONNECT_STRING);
    local hostname = iothub.ConnectionString.Parse(CONNECT_STRING).HostName;

    // Find this device
    registry.get(function(err, deviceInfo) {
        if (err) {
            if (err.response.statuscode == 404) {
                // No such device, let's create it
                registry.create(function(err, deviceInfo) {
                    if (err) {  
                        server.error(err.message);
                    } else {
                        server.log("Created " + deviceInfo.getBody().deviceId);
                        ::client <- iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
                        receive();
                    }
                }.bindenv(this));
            } else {
                server.error(err.message);
            }
        } else {
            server.log("Connected as " + deviceInfo.getBody().deviceId);
            ::client <- iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
            receive();
        }
    }.bindenv(this));

}

// Formats the date object as a UTC string
function formatDate(){
    local d = date();
    return format("%04d-%02d-%02d %02d:%02d:%02d", d.year, (d.month+1), d.day, d.hour, d.min, d.sec);
}

// Send an event to Azure IoT Hub
function sendEvent(message) {
    client.sendEvent(message, function(err, res) {
        if (err) {
            server.log("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
        }
    });
}

// Receive an event from Azure IoT Hub
function receive() {
    client.receive(function(err, message) {
        if (err) {
            server.log("receive error: " + err.message + " (" + err.response.statuscode + ")");
        } else {
            client.sendFeedback(iothub.HTTP.FEEDBACK_ACTION_COMPLETE, message);
            device.send("command", message.getData());
        }
    });
}

// Execution starts here ...

// Bootstrap the class and wait for the device to send events
connect();

// Called when device sends a log message
device.on("log", function(data) {

    data.type <- "log";
    data.timestamp <- formatDate();
    local message = iothub.Message(data);
    sendEvent(message);

})

// Called when device sends an alert message
device.on("alert", function(data) {

    data.type <- "alert";
    data.timestamp <- formatDate();
    local message = iothub.Message(data);
    sendEvent(message);

})


