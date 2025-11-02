package debug;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import openfl.system.System;
import haxe.Timer;

#if android
import android.widget.Toast as AndroidToast;
#end

enum LogLevel {  
    INFO;  
    WARNING;  
    ERROR;  
    FATAL;  
}

class DebugConsole extends FlxGroup
{
    var toggleButton:FlxSprite;
    var toggleButtonText:FlxText;
    var consolePanel:FlxSprite;
    var consoleText:FlxText;
    var copyButton:FlxSprite;
    var copyButtonText:FlxText;
    var clearButton:FlxSprite;
    var clearButtonText:FlxText;
    var headerText:FlxText;
    var logCountText:FlxText;
    
    var isVisible:Bool = false;
    var logs:Array<LogEntry> = [];
    
    var logScrollY:Float = 0;
    var maxScrollY:Float = 0;
    var lastTouchY:Float = 0;
    var isDragging:Bool = false;
    
    static inline var BUTTON_SIZE:Int = 80;
    static inline var PANEL_WIDTH:Int = 600;
    static inline var PANEL_HEIGHT:Int = 400;
    static inline var MAX_LOGS:Int = 100;
    
    public function new()
    {
        super();
        
        createToggleButton();
        createConsolePanel();
        hookTrace();
        
        consolePanel.visible = false;
        consoleText.visible = false;
        copyButton.visible = false;
        copyButtonText.visible = false;
        clearButton.visible = false;
        clearButtonText.visible = false;
        headerText.visible = false;
        logCountText.visible = false;
    }
    
    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);
        
        toggleButton.x = FlxG.width - BUTTON_SIZE - 10;
        toggleButton.y = FlxG.height - BUTTON_SIZE - 10;
        toggleButtonText.x = toggleButton.x;
        toggleButtonText.y = toggleButton.y;
        
        if (FlxG.mouse.justPressed || FlxG.touches.list.length > 0)
        {
            var mouseX = FlxG.mouse.x;
            var mouseY = FlxG.mouse.y;
            
            if (FlxG.touches.list.length > 0)
            {
                mouseX = FlxG.touches.list[0].x;
                mouseY = FlxG.touches.list[0].y;
            }
            
            if (toggleButton.overlapsPoint(new flixel.math.FlxPoint(mouseX, mouseY)))
            {
                toggleConsole();
            }
            else if (isVisible)
            {
                if (copyButton.overlapsPoint(new flixel.math.FlxPoint(mouseX, mouseY)))
                {
                    copyLogsToClipboard();
                }
                else if (clearButton.overlapsPoint(new flixel.math.FlxPoint(mouseX, mouseY)))
                {
                    clearLogs();
                }
                else if (consolePanel.overlapsPoint(new flixel.math.FlxPoint(mouseX, mouseY)))
                {
                    isDragging = true;
                    lastTouchY = mouseY;
                }
            }
        }
        
        if (isVisible && isDragging)
        {
            var currentY = FlxG.mouse.y;
            if (FlxG.touches.list.length > 0)
                currentY = FlxG.touches.list[0].y;
            
            var deltaY = currentY - lastTouchY;
            logScrollY = FlxMath.bound(logScrollY - deltaY, 0, maxScrollY);
            lastTouchY = currentY;
            updateConsoleText();
        }
        
        if (FlxG.mouse.justReleased || FlxG.touches.list.length == 0)
        {
            isDragging = false;
        }
    }
    
    function createToggleButton():Void
    {
        toggleButton = new FlxSprite();
        toggleButton.makeGraphic(BUTTON_SIZE, BUTTON_SIZE, 0x88FF0000);
        add(toggleButton);
        
        toggleButtonText = new FlxText(0, 0, BUTTON_SIZE, "D", 32);
        toggleButtonText.setFormat(null, 32, FlxColor.WHITE, CENTER);
        toggleButtonText.setBorderStyle(OUTLINE, FlxColor.BLACK, 2);
        add(toggleButtonText);
    }
    
    function createConsolePanel():Void
    {
        var panelX = (FlxG.width - PANEL_WIDTH) / 2;
        var panelY = 50;
        
        consolePanel = new FlxSprite(panelX, panelY);
        consolePanel.makeGraphic(PANEL_WIDTH, PANEL_HEIGHT, 0xDD000000);
        add(consolePanel);
        
        headerText = new FlxText(panelX + 10, panelY + 10, PANEL_WIDTH - 20, "DEBUG CONSOLE", 16);
        headerText.setFormat(null, 16, FlxColor.YELLOW, CENTER);
        headerText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        add(headerText);
        
        logCountText = new FlxText(panelX + 10, panelY + 35, PANEL_WIDTH - 20, "Logs: 0", 12);
        logCountText.setFormat(null, 12, FlxColor.WHITE, LEFT);
        logCountText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        add(logCountText);
        
        consoleText = new FlxText(panelX + 10, panelY + 60, PANEL_WIDTH - 20, "", 10);
        consoleText.setFormat(null, 10, FlxColor.WHITE, LEFT);
        consoleText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        add(consoleText);
        
        var buttonWidth = 120;
        var buttonHeight = 30;
        var buttonY = panelY + PANEL_HEIGHT - buttonHeight - 10;
        
        copyButton = new FlxSprite(panelX + 10, buttonY);
        copyButton.makeGraphic(Std.int(buttonWidth), Std.int(buttonHeight), 0xFF00AA00);
        add(copyButton);
        
        copyButtonText = new FlxText(copyButton.x, copyButton.y, buttonWidth, "COPY", 14);
        copyButtonText.setFormat(null, 14, FlxColor.WHITE, CENTER);
        copyButtonText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        add(copyButtonText);
        
        clearButton = new FlxSprite(panelX + buttonWidth + 20, buttonY);
        clearButton.makeGraphic(Std.int(buttonWidth), Std.int(buttonHeight), 0xFFAA0000);
        add(clearButton);
        
        clearButtonText = new FlxText(clearButton.x, clearButton.y, buttonWidth, "CLEAR", 14);
        clearButtonText.setFormat(null, 14, FlxColor.WHITE, CENTER);
        clearButtonText.setBorderStyle(OUTLINE, FlxColor.BLACK, 1);
        add(clearButtonText);
    }
    
    function hookTrace():Void  
	{  
	    var originalTrace = haxe.Log.trace;  
	    haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) {  
	        originalTrace(v, infos);  
	          
	        var location = "";  
	        if (infos != null)  
	            location = '${infos.fileName}:${infos.lineNumber}';  
	          
	        var entry:LogEntry = {  
	            timestamp: getTimestamp(),  
	            text: Std.string(v),  
	            level: INFO,  
	            location: location  
	        };  
	        logs.push(entry);  
	          
	        if (logs.length > MAX_LOGS)  
	            logs.shift();  
	          
	        updateConsoleText();  
	    };  
	}
    
    public function addLog(text:String, level:LogLevel, ?infos:haxe.PosInfos):Void  
	{  
	    var location = "";  
	    if (infos != null)  
	        location = '${infos.fileName}:${infos.lineNumber}';  
	      
	    logs.push({  
	        timestamp: getTimestamp(),  
	        text: text,  
	        level: level,  // Ahora usa LogLevel directamente  
	        location: location  
	    });  
	      
	    if (logs.length > MAX_LOGS)  
	        logs.shift();  
	      
	    updateConsoleText();  
	}
    
    function toggleConsole():Void
    {
        isVisible = !isVisible;
        
        consolePanel.visible = isVisible;
        consoleText.visible = isVisible;
        copyButton.visible = isVisible;
        copyButtonText.visible = isVisible;
        clearButton.visible = isVisible;
        clearButtonText.visible = isVisible;
        headerText.visible = isVisible;
        logCountText.visible = isVisible;
        
        if (isVisible)
            updateConsoleText();
    }
    
    function updateConsoleText():Void  
	{  
	    if (logs.length == 0)  
	    {  
	        consoleText.text = "No logs yet...";  
	        logCountText.text = "Logs: 0";  
	        maxScrollY = 0;  
	        return;  
	    }  
	      
	    logCountText.text = 'Logs: ${logs.length}';  
	      
	    var displayText = "";  
	    var lineHeight = 12;  
	    var maxVisibleLines = Std.int((PANEL_HEIGHT - 100) / lineHeight);  
	      
	    var startIndex = Std.int(logScrollY / lineHeight);  
	    var endIndex = Std.int(Math.min(startIndex + maxVisibleLines, logs.length));  
	      
	    for (i in startIndex...endIndex)  
	    {  
	        var log = logs[i];  
	        var levelPrefix = switch(log.level) {  
	            case INFO: "[INFO]";  
	            case WARNING: "[WARN]";  
	            case ERROR: "[ERROR]";  
	            case FATAL: "[FATAL]";  
	        }  
	        displayText += '[${log.timestamp}] $levelPrefix ${log.text}\n';  
	        if (log.location != "")  
	            displayText += '  @ ${log.location}\n';  
	    }  
	      
	    consoleText.text = displayText;  
	      
	    var totalLines = logs.length * 2;  
	    maxScrollY = Math.max(0, (totalLines - maxVisibleLines) * lineHeight);  
	}
    
    function copyLogsToClipboard():Void  
	{  
	    var fullText = "";  
	    for (log in logs)  
	    {  
	        var levelPrefix = switch(log.level) {  
	            case INFO: "[INFO]";  
	            case WARNING: "[WARN]";  
	            case ERROR: "[ERROR]";  
	            case FATAL: "[FATAL]";  
	        }  
	        fullText += '[${log.timestamp}] $levelPrefix ${log.text}';  
	        if (log.location != "")  
	            fullText += ' @ ${log.location}';  
	        fullText += '\n';  
	    }  
	      
	    #if android  
	    try {  
	        System.setClipboard(fullText);  
	        AndroidToast.makeText("Logs copied to clipboard!", AndroidToast.LENGTH_SHORT);  
	    } catch (e:Dynamic) {  
	        trace('Failed to copy to clipboard: $e');  
	    }  
	    #else  
	    System.setClipboard(fullText);  
	    trace('Logs copied to clipboard!');  
	    #end  
	}
    
    function clearLogs():Void
    {
        logs = [];
        updateConsoleText();
        
        #if android
        AndroidToast.makeText("Logs cleared!", AndroidToast.LENGTH_SHORT);
        #end
    }
    
    function getTimestamp():String
    {
        var now = Date.now();
        return DateTools.format(now, "%H:%M:%S");
    }
}

typedef LogEntry = {  
    var timestamp:String;  
    var text:String;  
    var level:LogLevel;  // Cambiar de FlxColor a LogLevel  
    var location:String;  
}