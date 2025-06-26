#ifndef SCREENS_H
#define SCREENS_H

#include "displays.h"
#include "inputs.h"
#include "firebase_handler.h"
#include "audio_handler.h"
#include "png_handler.h"

#define FIRST_OPTION 0
#define SECOND_OPTION 1
#define CONFIRM 4
#define RETURN 5

class Screens {
public:
    typedef enum ScreenChoice {
        CHOOSE_MODE_SCREEN,
        WIFI_CONNECTION_SCREEN,
        QR_SCREEN,
        OFFLINE_POMODORO_SETTINGS_SCREEN,
        ONLINE_SESSION_PLANER_SCREEN,
        POMODORO_TIMER_SCREEN
    } ScreenChoice;

    typedef enum Options {
        ONLINE,
        OFFLINE
    } Options;

    Screens(Audio& audio);
    void init();
    void displayCurrentScreen(bool update);
    void chooseModeScreen(bool update);
    void qrScreen(bool update);
    void offlinePomodoroSettingsScreen(bool update);
    void onlineSessionPlannerScreen(bool update);
    void pomodoroTimerScreen(bool update);
    void updateselectedInputIndex(int value);
    void adjustSelectedValue(int delta);
    int getChoice();
    ScreenChoice getCurrentScreen();
    void switchScreen(ScreenChoice nextScreen);
private:
    Audio& audio;
    void handleValuesChange(int* value);
    ScreenChoice currentScreen;
    int selectedInputIndex;
    int currentTotalOptions;
    bool roterySlower;
    int initValues[4] = {25, 5, 15, 4}; // pomodoroLength, shortBreakLength, longBreakLength, longBreakAfter
    int valuesSize = 4;
    FirebaseJson userData;
    unsigned long pomodoroStartTime;
    int currentPomodoroMinutes;
    bool isPomodoroRunning;
    bool isPomodoroTimerPaused;
    unsigned long pausedElapsedTime;
    int pomodoroCount;
    String lastTimerStr;
    String sessionName; // Added for session name
    String sessionId;   // Added to track current session ID
    unsigned long lastFaceUpdate;
    FaceType currentFace;
    const unsigned long FACE_UPDATE_INTERVAL = 10000;
};
#endif