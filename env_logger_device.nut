#require "Si702x.class.nut:1.0.0"

logging <- true; 

eventData <- {};
eventData.temp <- 0;
eventData.humid <- 0;

const PERIOD = 2;
const ARRSIZE = 5;
tempArr <- array(ARRSIZE);
humidArr <- array(ARRSIZE);
for (local i=0; i<ARRSIZE; i++) {
    tempArr[i] = 0.0;
    humidArr[i] = 0.0;
}
idx <- -1;
const TEMPTHRES = 30.0;
const HUMIDTHRES = 60.0;

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tempHumid <- Si702x(hardware.i2c89);


// Create a function that will be called in a minute loop
function getData() {
    imp.wakeup(PERIOD, getData);
    
    tempHumid.read(function(result) {
        if ("err" in result) {
            server.error(result.err);
            return;
        }
        
        idx++;
        if (idx >= ARRSIZE) idx = 0;
        tempArr[idx] = result.temperature;
        humidArr[idx] = result.humidity;
        
//        data.temp = result.temperature;
//        data.humid = result.humidity;
//        server.log(format("temp: %.01f°C, humid: %.01f%%", data.temp, data.humid));

        if (logging) {
            computeLog();
        } else {
            computeAlert();
        }

    });
    
}

function computeLog() {
    eventData.temp = tempArr[idx];
    eventData.humid = humidArr[idx];
    server.log(format("temp: %.01f°C, humid: %.01f%%", eventData.temp, eventData.humid));
    blink2();
    agent.send("log", eventData);
}

function computeAlert() {
    blink1();

    local temp = 0.0;
    local humid = 0.0;
    // compute average, etc
    for (local i=0; i<ARRSIZE; i++) {
        temp += tempArr[i];
        humid += humidArr[i];
    }
    temp = temp / ARRSIZE;
    humid = humid / ARRSIZE;
    server.log(format("avg: temp: %.01f°C, humid: %.01f%%", temp, humid));
    
    if ((temp >= TEMPTHRES) && (humid >= HUMIDTHRES)) {
        server.log(format("ALERT: temp: %.01f°C, humid: %.01f%%", temp, humid));
        eventData.temp = temp;
        eventData.humid = humid;
        agent.send("alert", eventData);
        blink3();
    }
}

function blink1() {
    ledPin.write(1);
    imp.sleep(0.05);
    ledPin.write(0);
}

function blink2() {
    ledPin.write(1);
    imp.sleep(0.5);
    ledPin.write(0);
}

function blink3() {
    for (local i = 10; i--; i >0) {
        ledPin.write(1);
        imp.sleep(0.1);
        ledPin.write(0);
        imp.sleep(0.1);
    }
}

agent.on("command", function(command) {
    switch (command) {
        case "log":
            logging <- true;
            server.log("mode: logging")
            break;
        case "alert":
            server.log(format("mode: alerting (thresholds - temp: %.01f°C, humid: %.01f%%", 
                TEMPTHRES, HUMIDTHRES));
            logging <- false;
            break;
        default:
            server.error("illegal command")
            break;
    }

})

ledPin <- hardware.pin2;
ledPin.configure(DIGITAL_OUT, 0);

// Now bootstrap the loop
imp.wakeup(5, getData);
