#require "Si702x.class.nut:1.0.0"

//
// Environmental Logger Demo integrated with Azure IoT Hub
// Device
//

logging <- true; 

const PERIOD = 2; // sensor reading period

// Array to compute averages
const ARRSIZE = 5; 
tempArr <- array(ARRSIZE);
humidArr <- array(ARRSIZE);
for (local i=0; i<ARRSIZE; i++) {
    tempArr[i] = 0.0;
    humidArr[i] = 0.0;
}
idx <- -1;

// Temp and humidity thresholds
const TEMPTHRES = 30.0;
const HUMIDTHRES = 60.0;

// Initialize I2C and sensor
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tempHumid <- Si702x(hardware.i2c89);

// Periodically get data
function getData() {
    imp.wakeup(PERIOD, getData); // schedule next call
    
    tempHumid.read(function(result) {
        if ("err" in result) {
            server.error(result.err);
            return;
        }
        
        // Move to next slot and store values
        idx++;
        if (idx >= ARRSIZE) idx = 0;
        tempArr[idx] = result.temperature;
        humidArr[idx] = result.humidity;

        // Logging or alerting mode?
        if (logging) {
            modeLog();
        } else {
            modeAlert();
        }

    });
    
}

// Log mode
function modeLog() {

    local eventData = {};
    eventData.temp <- 0.0;
    eventData.humid <- 0.0;

    blink2();
    
    // Copy to table
    eventData.temp = tempArr[idx];
    eventData.humid = humidArr[idx];
    server.log(format("temp: %.01f°C, humid: %.01f%%", eventData.temp, eventData.humid));

    // Send message to agent
    agent.send("log", eventData);
}

// Alert mode
function modeAlert() {

    local eventData = {};
    eventData.temp <- 0.0;
    eventData.humid <- 0.0;
    
    local avgTemp = 0.0;
    local avgHumid = 0.0;
    
    blink1();

    // Compute averages
    for (local i=0; i<ARRSIZE; i++) {
        avgTemp += tempArr[i];
        avgHumid += humidArr[i];
    }
    avgTemp = avgTemp / ARRSIZE;
    avgHumid = avgHumid / ARRSIZE;
    server.log(format("avg: temp: %.01f°C, humid: %.01f%%", avgTemp, avgHumid));
    
    if ((avgTemp >= TEMPTHRES) && (avgHumid >= HUMIDTHRES)) {
        server.log(format("ALERT!"));
        
        // Copy to table
        eventData.temp = avgTemp;
        eventData.humid = avgHumid;
        // Send message to agent
        agent.send("alert", eventData);
        
        blink3();
    }
}

// Alert mode heartbeat
function blink1() {
    ledPin.write(1);
    imp.sleep(0.05);
    ledPin.write(0);
}

// Logging mode heartbeat
function blink2() {
    ledPin.write(1);
    imp.sleep(0.5);
    ledPin.write(0);
}

// Alert signal
function blink3() {
    for (local i = 5; i--; i >0) {
        ledPin.write(1);
        imp.sleep(0.1);
        ledPin.write(0);
        imp.sleep(0.1);
    }
}

// Called when agent sends a command
agent.on("command", function(command) {
    switch (command) {
        case "log":
            // Turn on logging mode
            logging <- true;
            server.log("mode: logging")
            break;
        case "alert":
            // Turn on alert mode
            server.log(format("mode: alerting (thresholds - temp: %.01f°C, humid: %.01f%%", 
                TEMPTHRES, HUMIDTHRES));
            logging <- false;
            break;
        default:
            server.error("illegal command")
            break;
    }

})

// Execution starts here ...

// Configure LED
ledPin <- hardware.pin2;
ledPin.configure(DIGITAL_OUT, 0);

// Now bootstrap the loop
imp.wakeup(5, getData);
