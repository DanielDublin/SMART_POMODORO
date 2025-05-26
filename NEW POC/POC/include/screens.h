#ifndef SCREENS_H
#define SCREENS_H

#include "displays.h"
#include "inputs.h"
#include "firebase_handler.h"

#define FIRST_OPTION 0 //all in one enum or in define????????? fix in loop later
#define SECOND_OPTION 1
#define CONFIRM 4
#define RETURN 5

class Screens {
public:
    typedef enum Screen {
        CHOOSE_MODE_SCREEN,
        WIFI_CONNECTION_SCREEN,
        OFFLINE_POMODORO_SETTINGS_SCREEN,
        ONLINE_SESSION_PLANER_SCREEN,
        CLOCK_SCREEN
    } Screen;

    typedef enum Options {
        ONLINE,
        OFFLINE
    } Options;

    Screens();
    void init() {Serial.printf("currentScreen: %d, selectedInputIndex: %d, currentTotalOptions: %d\n", currentScreen,selectedInputIndex,currentTotalOptions);}
    void displayCurrentScreen(bool update);
    void chooseModeScreen(bool update);
    void offlinePomodoroSettingsScreen(bool update);
    void onlineSessionPlannerScreen(bool update);
    void updateselectedInputIndex(int value); 
    int getChoice();
    Screen getCurrentScreen();
    void switchScreen(Screen nextScreen);
private:
    void handleValuesChange(int* value);
    Screen currentScreen;
    int selectedInputIndex;
    int currentTotalOptions;
    bool roterySlower;
    int initValuesForOffline[4] = {30, 5, 30, 4};
    int valuesSize = 4;
    FirebaseJson userData;
};
#endif 