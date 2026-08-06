package com.davidmorales.pr;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "WorkoutTimer")
public class WorkoutTimerPlugin extends Plugin {

    private void send(String action, String routineName) {
        Context ctx = getContext();
        Intent intent = new Intent(ctx, WorkoutTimerService.class);
        intent.setAction(action);
        if (routineName != null) {
            intent.putExtra(WorkoutTimerService.EXTRA_NAME, routineName);
        }
        if (WorkoutTimerService.ACTION_START.equals(action)
                && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.startForegroundService(intent);
        } else {
            ctx.startService(intent);
        }
    }

    @PluginMethod
    public void start(PluginCall call) {
        String name = call.getString("routineName", "Entrenamiento");
        send(WorkoutTimerService.ACTION_START, name);
        call.resolve();
    }

    @PluginMethod
    public void pause(PluginCall call) {
        send(WorkoutTimerService.ACTION_PAUSE, null);
        call.resolve();
    }

    @PluginMethod
    public void resume(PluginCall call) {
        send(WorkoutTimerService.ACTION_RESUME, null);
        call.resolve();
    }

    @PluginMethod
    public void stop(PluginCall call) {
        send(WorkoutTimerService.ACTION_STOP, null);
        call.resolve();
    }
}
