#include "screens.h"

Screens::Screens(Audio& audio) : audio(audio), currentScreen(CHOOSE_MODE_SCREEN), selectedInputIndex(0), currentTotalOptions(2),
                                roterySlower(false), pomodoroStartTime(0), currentPomodoroMinutes(0),
                                isPomodoroRunning(false), isPomodoroTimerPaused(false), pausedElapsedTime(0),
                                pomodoroCount(0), lastTimerStr(""),
                                sessionName(""), sessionId(""),
                                lastFaceUpdate(0), currentFace(FACE_FOCUSED) {}

void Screens::init() {
    clearTFTScreen();
    clearOLEDScreen();
    String prompt = "Welcome to Study Timer";
    displayTFTText(prompt, centerTextX(prompt, 3), 100, 3, TFT_BLUE, true);
    delay(2000);
    clearTFTScreen();
    displayCurrentScreen(true);
}

bool Screens::updateselectedInputIndex(int value) {
    if (!roterySlower) {
        if (value > 0) {
            if (currentTotalOptions <= 1) {
                return false;
            }
            else {
                selectedInputIndex++;
                selectedInputIndex = selectedInputIndex % currentTotalOptions;
            }
        } else {
            if (currentTotalOptions <= 1) {
                return false;
            }
            else {
                selectedInputIndex--;
                selectedInputIndex = abs(selectedInputIndex) % currentTotalOptions;
            }
        }
        audio.playButton(0.7);
        Serial.printf("selectedInputIndex: %d\n", selectedInputIndex);
        displayCurrentScreen(true);
        return true;
    } else {
        roterySlower = !roterySlower;
        return true;
    }
}

void Screens::displayCurrentScreen(bool update) {
    if (currentScreen == CHOOSE_MODE_SCREEN) {
        chooseModeScreen(update);
    } else if (currentScreen == OFFLINE_POMODORO_SETTINGS_SCREEN) {
        offlinePomodoroSettingsScreen(update);
    } else if (currentScreen == ONLINE_SESSION_PLANER_SCREEN) {
        onlineSessionPlannerScreen(update);
    } else if (currentScreen == POMODORO_TIMER_SCREEN) {
        pomodoroTimerScreen(update);
    } else if (currentScreen == QR_SCREEN) {
        qrScreen(update);
    } else if (currentScreen == WIFI_CONNECTION_SCREEN) {
        wifiNotConnectedScreen(update);
    } else if (currentScreen == USER_PLANS_SCREEN) {
        userPlansScreen(update);
    } else if (currentScreen == SESSION_SUMMARY_SCREEN) {
        sessionSummaryScreen(update);
    }
}

void Screens::chooseModeScreen(bool update) {
    sessionId = "";
    currentTotalOptions = 2;
    std::vector<String> options = {"Online", "Offline"};
    drawMenu(options, selectedInputIndex, 200, update);
    String prompt = "Choose Wi-Fi mode:";
    displayTFTText(prompt, centerTextX(prompt, 3), 100, 3, TFT_BLUE, false);
}

void Screens::qrScreen(bool update) {
    sessionId = "";
    currentTotalOptions = 1;
    std::vector<String> options = {"Return"};
    drawMenu(options, selectedInputIndex, 300, update);
    png_handler::drawQR();
    handleInitialPairing();
}

void Screens::wifiNotConnectedScreen(bool update) {
    sessionId = "";
    currentTotalOptions = 2;
    std::vector<String> options = {"Return", "Retry"};
    drawMenu(options, selectedInputIndex, 200, update);
    String prompt = "No network detected, connect to Wi-Fi";
    displayTFTText(prompt, centerTextX(prompt, 2), 100, 2, TFT_RED, false);
}

void Screens::userPlansScreen(bool update) {
    if (millis() - lastPollTime >= POLLING_INTERVAL || update) {
        String prompt = "Choose Plan";
        displayTFTText(prompt, centerTextX(prompt, 3), 50, 3, TFT_BLUE, false);
        String data = processFirebase();
        std::vector<std::pair<String, String>> sessions = extractSessionNameIdPairs(data);
        std::vector<String> names = extractNamesFromPairs(sessions);
        names.push_back("Return");
        currentTotalOptions = names.size();
        drawMenu(names, selectedInputIndex, 100, update);
        sessionId = selectedInputIndex != names.size() - 1 ? sessions[selectedInputIndex].second : "";
        Serial.printf("userPlansScreen sesionIF: %s\n", sessionId);
        lastPollTime = millis();
    }
}

void Screens::handleValuesChange(int* value) {
    if (*value < 0) return;
    int rotaryValue = handleRotaryEncoder();
    if (rotaryValue != 0) {
        int newValue = *value + rotaryValue;
        if (newValue < 1) {
            newValue = 1;
        }
        *value = newValue;
    }
}

void Screens::offlinePomodoroSettingsScreen(bool update) {
    currentTotalOptions = 6;
    std::vector<String> options = {"Confirm", "Return"};
    int optionsSize = sizeof(options) / sizeof(options[0]);
    String prompt = "Settings";
    String pomodoroLenStr = "Pomodoro Duration: ";
    String shortBreakLenStr = "Short Break Duration: ";
    String longBreakLenStr = "Long Break Duration: ";
    String longBreakAfterStr = "Long Break After: ";
    displayTFTText(prompt, centerTextX(prompt, 3), 0, 3, TFT_BLUE, false);
    displayTFTText(pomodoroLenStr, 0, 50, 2, TFT_BLUE, false);
    displayTFTText(shortBreakLenStr, 0, 100, 2, TFT_BLUE, false);
    displayTFTText(longBreakLenStr, 0, 150, 2, TFT_BLUE, false);
    displayTFTText(longBreakAfterStr, 0, 200, 2, TFT_BLUE, false);
    if (selectedInputIndex < valuesSize) {
        handleValuesChange(&initValues[selectedInputIndex]);
    }
    drawValues(initValues, valuesSize, options, selectedInputIndex, 50, update);
}

void Screens::onlineSessionPlannerScreen(bool update) {
    currentTotalOptions = 2;
    std::vector<String> options = {"Confirm", "Return"};
    
    String prompt = "Session Planner";
    String sessionNameStr = "Session: ";
    String deadlineStr = "Deadline: ";
    String sessionsPerDayStr = "Sessions per day: ";
    String studyDaysStr = "Study days: ";
    displayTFTText(prompt, centerTextX(prompt, 3), 0, 3, TFT_BLUE, false);
    displayTFTText(sessionNameStr, 0, 50, 2, TFT_BLUE, false);
    displayTFTText(deadlineStr, 0, 100, 2, TFT_BLUE, false);
    displayTFTText(sessionsPerDayStr, 0, 150, 2, TFT_BLUE, false);
    displayTFTText(studyDaysStr, 0, 200, 2, TFT_BLUE, false);

    String rawUserData;
    if (sessionId == "") {
        String data = processFirebase();
        std::vector<std::pair<String, String>> sessions = extractSessionNameIdPairs(data);
        sessionId = sessions[0].second;
    }
    Serial.print("session: ");
    Serial.println(sessionId);
    if (readSessionData(rawUserData, pairedUid, sessionId)) {
        userData.setJsonData(rawUserData);
    } else {
        displayTFTText("Failed to load session", 0, 250, 2, TFT_RED, false);
        return;
    }
    Serial.println("---------------------------------------------------------");
    Serial.println(rawUserData);
    Serial.println("---------------------------------------------------------");

    FirebaseJsonData data;
    String deadline, sessionsPerDay, studyDays;
    if (userData.get(data, "fields/pomodoroLength/integerValue")) {
        initValues[0] = data.intValue;
    }
    if (userData.get(data, "fields/shortBreakLength/integerValue")) {
        initValues[1] = data.intValue;
    }
    if (userData.get(data, "fields/longBreakLength/integerValue")) {
        initValues[2] = data.intValue;
    }
    if (userData.get(data, "fields/longBreakAfter/integerValue")) {
        initValues[3] = data.intValue;
    }
    if (userData.get(data, "fields/sessionName/stringValue")) {
        sessionName = data.stringValue;
    }
    if (userData.get(data, "fields/examDeadline/timestampValue")) {
        deadline = data.stringValue;
    }
    if (userData.get(data, "fields/sessionsPerDay/integerValue")) {
        sessionsPerDay = data.stringValue;
        initValues[4] = data.intValue;
    }
    if (userData.get(data, "fields/selectedDays/arrayValue/values")) {
        FirebaseJsonArray arr;
        data.getArray(arr);
        String days = "";
        for (size_t i = 0; i < arr.size(); i++) {
            FirebaseJsonData day;
            arr.get(day, i);
            String dayStr = day.stringValue;
            days += dayStr.substring(8, 10) + "/" + dayStr.substring(5, 7);
            if (i < arr.size() - 1) days += ", ";
        }
        studyDays = days;
    }

    String deadlineFormatted = deadline.substring(8, 10) + "/" + deadline.substring(5, 7);
    displayTFTText(sessionName, 300, 50, 2, TFT_BLUE, false);
    displayTFTText(deadlineFormatted, 300, 100, 2, TFT_BLUE, false);
    displayTFTText(sessionsPerDay, 300, 150, 2, TFT_BLUE, false);
    displayTFTText(studyDays, 300, 200, 2, TFT_BLUE, false);

    drawMenu(options, selectedInputIndex, 250, update);
}

void Screens::sessionSummaryScreen(bool update) {
    currentTotalOptions = 1;
    std::vector<String> options = {"Return"};
    String prompt = "Sessions Summary";

    displayTFTText(prompt, centerTextX(prompt, 3), 0, 3, TFT_BLUE, false);

    String rankStr = "Rank: 30";    //change from hardcoded
    displayTFTText(rankStr, 0, 50, 2, TFT_WHITE, false);

    // Calculate and display Time studied
    unsigned long elapsedSeconds = (isPomodoroRunning && !isPomodoroTimerPaused) 
        ? (millis() - pomodoroStartTime) / 1000 + pausedElapsedTime / 1000 
        : 0;
    int totalMinutes = (currentPomodoroMinutes * 60 - elapsedSeconds) / 60 + (pomodoroCount * currentPomodoroMinutes);
    String timeStudiedStr = "Time studied: " + String(totalMinutes) + " minutes";
    displayTFTText(timeStudiedStr, 0, 100, 2, TFT_WHITE, false);

    // Display Completed Sessions
    int completedSessions = pomodoroCount; // Track completed sessions from Pomodoro cycles
    String completedSessionsStr = "Completed Sessions: " + String(completedSessions);
    displayTFTText(completedSessionsStr, 0, 150, 2, TFT_WHITE, false);


    int plannedSessions = initValues[4];
    if (pairingState == PairingState::PAIRED) {
        // Online mode: Fetch planned sessions from Firebase if available
        String rawUserData;
        if (readSessionData(rawUserData, pairedUid, sessionId)) {
            userData.setJsonData(rawUserData);
            FirebaseJsonData data;
            if (userData.get(data, "fields/sessionsPerDay/integerValue") && 
                userData.get(data, "fields/selectedDays/arrayValue/values")) {
                FirebaseJsonArray arr;
                data.getArray(arr);
                plannedSessions = data.intValue * arr.size(); // Sessions per day * number of days
            }
        }
    }     
    int progressPercentage = (completedSessions * 100) / (plannedSessions > 0 ? plannedSessions : 1);
    displayProgressBar(progressPercentage, false); // false for TFT

    // Draw menu options
    drawMenu(options, selectedInputIndex, 250, update);
}

void Screens::adjustSelectedValue(int delta) {
    if (currentScreen == OFFLINE_POMODORO_SETTINGS_SCREEN && selectedInputIndex < valuesSize) {
        int newValue = initValues[selectedInputIndex] + delta;
        if (newValue >= 1) {
            initValues[selectedInputIndex] = newValue;
            audio.playButton(0.7);
        }
    }
}

void Screens::pomodoroTimerScreen(bool update) {
    currentTotalOptions = 2;
    std::vector<String> options = {"Stop", isPomodoroTimerPaused ? "Resume" : "Pause"};

    if (!isPomodoroRunning) {
        pomodoroStartTime = millis();
        isPomodoroRunning = true;
        isPomodoroTimerPaused = false;
        pausedElapsedTime = 0;
        currentPomodoroMinutes = initValues[0];
        lastTimerStr = "";
        lastFaceUpdate = millis();
        currentFace = FACE_FOCUSED;
        pomodoroCount = 0;
        
        clearTFTScreen();
        clearOLEDScreen();
        String sessionType = "Focus Time";
        displayTFTText(sessionType, centerTextX(sessionType, 3), 50, 3, TFT_BLUE, false);
        drawMenu(options, selectedInputIndex, 250, true);
        displayOLEDFace(currentFace);
    }
    
    unsigned long currentTime = millis();
    if (currentTime - lastFaceUpdate >= FACE_UPDATE_INTERVAL) {
        currentFace = (currentFace == FACE_FOCUSED) ? FACE_TIRED : FACE_FOCUSED;
        displayOLEDFace(currentFace);
        lastFaceUpdate = currentTime;
    }

    unsigned long elapsedSeconds;
    if (isPomodoroTimerPaused) {
        elapsedSeconds = pausedElapsedTime / 1000;
    } else {
        elapsedSeconds = (millis() - pomodoroStartTime) / 1000;
    }
    
    int totalSeconds = (currentPomodoroMinutes * 60) - elapsedSeconds;
    int remainingMinutes = totalSeconds / 60;
    int remainingSeconds = totalSeconds % 60;

    if (totalSeconds <= 0) {
        clearTFTScreen();
        clearOLEDScreen();
        audio.playCharSound(true, 0.4);
        pomodoroCount++;
        lastTimerStr = "";
        
        if (pairingState == PairingState::PAIRED && currentScreen == POMODORO_TIMER_SCREEN) {
            FirebaseJson json;
            time_t now = time(nullptr);
            char timestamp[30];
            strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
            json.set("fields/completedAt/timestampValue", String(timestamp));
            json.set("fields/duration/integerValue", initValues[0]);
            json.set("fields/type/stringValue", pomodoroCount % initValues[3] == 0 ? "long_break" : pomodoroCount % 2 == 0 ? "short_break" : "pomodoro");
            json.set("fields/sessionName/stringValue", sessionName);
            String logId = "log_" + String(timestamp);
            if (writeSessionLog(pairedUid, logId, json)) {
                displayTFTText("Session logged!", 0, 200, 2, TFT_GREEN, false);
            } else {
                displayTFTText("Failed to log session", 0, 200, 2, TFT_RED, false);
            }
        }
        
        if (pomodoroCount == initValues[4]) {
            switchScreen(SESSION_SUMMARY_SCREEN);
            isPomodoroRunning = false;
            displayCurrentScreen(update);
            return;
        }
        if (pomodoroCount % initValues[3] == 0) {
            currentPomodoroMinutes = initValues[2];
            String message = "Long Break Time!";
            displayTFTText(message, centerTextX(message, 3), 50, 3, TFT_GREEN, false);
        } else {
            currentPomodoroMinutes = initValues[1];
            String message = "Short Break Time!";
            displayTFTText(message, centerTextX(message, 3), 50, 3, TFT_GREEN, false);
        }
        currentFace = FACE_TIRED;
        displayOLEDFace(currentFace);
        pomodoroStartTime = millis();
        lastFaceUpdate = millis();
        drawMenu(options, selectedInputIndex, 250, true);
        return;
    }

    String newTimerStr = String(remainingMinutes) + ":" + (remainingSeconds < 10 ? "0" : "") + String(remainingSeconds);
    
    if (newTimerStr != lastTimerStr) {
        int size = 4;
        int timerWidth = getDigitWidth(size) * newTimerStr.length() + getDigitWidth(size)/2;
        int timerX = (ILI_SCREEN_WIDTH - timerWidth) / 2;
        displayTFTTimer(newTimerStr, lastTimerStr, timerX, 150, size, TFT_WHITE);
        lastTimerStr = newTimerStr;
    }

    if (update) {
        drawMenu(options, selectedInputIndex, 250, false);
    }
}

int Screens::getChoice() {
    if (currentScreen == CHOOSE_MODE_SCREEN) {
        if (selectedInputIndex == ONLINE) {
            return ONLINE;
        }
        return OFFLINE;
    } else if (currentScreen == OFFLINE_POMODORO_SETTINGS_SCREEN) {
        if (selectedInputIndex < 4) {
            return selectedInputIndex;
        } else if (selectedInputIndex == CONFIRM) {
            return CONFIRM;
        }
        return RETURN;
    } else if (currentScreen == ONLINE_SESSION_PLANER_SCREEN) {
        if (selectedInputIndex == 0) {
            return CONFIRM;
        } else if (selectedInputIndex == 1) {
            return RETURN;
        }
        return -1;
    } else if (currentScreen == POMODORO_TIMER_SCREEN) {
        if (selectedInputIndex == 0) {
            isPomodoroRunning = false;
            return FIRST_OPTION;
        } else if (selectedInputIndex == 1) {
            if (isPomodoroTimerPaused) {
                pomodoroStartTime = millis() - pausedElapsedTime;
                isPomodoroTimerPaused = false;
            } else {
                pausedElapsedTime = millis() - pomodoroStartTime;
                isPomodoroTimerPaused = true;
            }
            audio.playButton(0.7);
            displayCurrentScreen(true);
            return -1;
        }
    }
    else if (currentScreen == QR_SCREEN){
        if (selectedInputIndex == FIRST_OPTION) {
            return FIRST_OPTION;
        }
    }
    else if (currentScreen == WIFI_CONNECTION_SCREEN){
        if (selectedInputIndex == FIRST_OPTION) {
            return FIRST_OPTION;
        }
        if (selectedInputIndex == SECOND_OPTION) {
            return SECOND_OPTION;
        }
    }
    else if (currentScreen == USER_PLANS_SCREEN) {
        if (sessionId != "")
            return FIRST_OPTION;
        return RETURN;
    }
    else if (currentScreen == SESSION_SUMMARY_SCREEN) {
        if (selectedInputIndex == 0) {
            return RETURN;
        }
    }
    return -1; 
}

Screens::ScreenChoice Screens::getCurrentScreen() {
    return currentScreen;
}

void Screens::switchScreen(ScreenChoice nextScreen) {
    clearTFTScreen();
    selectedInputIndex = 0;
    currentScreen = nextScreen;
}

std::vector<std::pair<String, String>> Screens::extractSessionNameIdPairs(const String& jsonString) {
    std::vector<std::pair<String, String>> sessionPairs;
    StaticJsonDocument<4096> doc;

    DeserializationError error = deserializeJson(doc, jsonString);
    if (error) {
        Serial.print(F("deserializeJson() failed: "));
        Serial.println(error.f_str());
        return sessionPairs;
    }

    JsonArray documents = doc["documents"].as<JsonArray>();
    for (JsonObject doc : documents) {
        JsonObject fields = doc["fields"];

        if (fields.containsKey("sessionName") && fields.containsKey("sessionId")) {
            const char* name = fields["sessionName"]["stringValue"];
            const char* id = fields["sessionId"]["stringValue"];
            sessionPairs.push_back(std::make_pair(String(name), String(id)));
        }
    }

    return sessionPairs;
}

std::vector<String> Screens::extractNamesFromPairs(const std::vector<std::pair<String, String>>& pairs) {
    std::vector<String> names;
    for (const auto& p : pairs) {
        names.push_back(p.first);
    }
    return names;
}