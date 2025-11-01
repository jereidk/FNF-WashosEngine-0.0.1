package backend.texture;  
  
import lime.graphics.opengl.GL;  
import openfl.display3D.textures.RectangleTexture;  
import openfl.display.BitmapData;  
import flixel.FlxG;   
  
import lime.utils.ArrayBufferView;  
import sys.io.File;  
import haxe.io.Bytes;  
  
class ASTCTexture {  
    // Definir constantes ASTC manualmente (Lime no las incluye)  
    static inline var COMPRESSED_RGBA_ASTC_4x4_KHR:Int = 0x93B0;  
    static inline var COMPRESSED_RGBA_ASTC_5x4_KHR:Int = 0x93B1;  
    static inline var COMPRESSED_RGBA_ASTC_5x5_KHR:Int = 0x93B2;  
    static inline var COMPRESSED_RGBA_ASTC_6x5_KHR:Int = 0x93B3;  
    static inline var COMPRESSED_RGBA_ASTC_6x6_KHR:Int = 0x93B4;  
    static inline var COMPRESSED_RGBA_ASTC_8x5_KHR:Int = 0x93B5;  
    static inline var COMPRESSED_RGBA_ASTC_8x6_KHR:Int = 0x93B6;  
    static inline var COMPRESSED_RGBA_ASTC_8x8_KHR:Int = 0x93B7;  
    static inline var COMPRESSED_RGBA_ASTC_10x5_KHR:Int = 0x93B8;  
    static inline var COMPRESSED_RGBA_ASTC_10x6_KHR:Int = 0x93B9;  
    static inline var COMPRESSED_RGBA_ASTC_10x8_KHR:Int = 0x93BA;  
    static inline var COMPRESSED_RGBA_ASTC_10x10_KHR:Int = 0x93BB;  
    static inline var COMPRESSED_RGBA_ASTC_12x10_KHR:Int = 0x93BC;  
    static inline var COMPRESSED_RGBA_ASTC_12x12_KHR:Int = 0x93BD;  
  
    public var texture:RectangleTexture;   
    public var width:Int;  
    public var height:Int;  
    public var blockWidth:Int;  
    public var blockHeight:Int;  
  
    static var astcSupported:Null<Bool> = null;  
  
    public function new(path:String, ?manualWidth:Int, ?manualHeight:Int) {      
        if (!checkASTCSupport()) throw "ASTC textures not supported on this device";      
          
        try {      
            if (!sys.FileSystem.exists(path)) throw 'ASTC file not found: $path';      
            var data:Bytes = File.getBytes(path);      
            if (data == null || data.length < 16) throw 'Invalid ASTC file: $path';      
            if (!validateASTCHeader(data)) throw 'Invalid ASTC header: $path';      
          
            var dims = readASTCDimensions(data);      
            this.width = manualWidth != null ? manualWidth : dims.width;      
            this.height = manualHeight != null ? manualHeight : dims.height;      
            this.blockWidth = dims.blockWidth;      
            this.blockHeight = dims.blockHeight;      
          
            if (width <= 0 || height <= 0) throw 'Invalid dimensions: ${width}x${height}';      
          
            trace('Loading ASTC: $path (${width}x${height}, block ${blockWidth}x${blockHeight})');      
          
            var context = FlxG.stage.context3D;  
            this.texture = context.createRectangleTexture(width, height, BGRA, false);  
  
            @:privateAccess  
            var glTexture:lime.graphics.opengl.GLTexture = texture.__textureID;  
          
            GL.bindTexture(GL.TEXTURE_2D, glTexture);  
            var format = getASTCFormat(blockWidth, blockHeight);      
          
            // era: ArrayBufferView(length, offset, data)  
            var astcData = data.sub(16, data.length - 16);  
            GL.compressedTexImage2D(      
                GL.TEXTURE_2D, 0, format, width, height, 0,  
                astcData.length,      
                new ArrayBufferView(astcData.length, 0, astcData)  
            );      
          
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);      
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);      
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);      
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);      
            GL.bindTexture(GL.TEXTURE_2D, null);  
  
        }      
        catch (e:Dynamic) {      
            trace('Error loading ASTC texture from $path: $e');      
            dispose();      
            throw e;      
        }      
    }  
  
    public function dispose():Void {  
        if (texture != null) {  
            texture.dispose();   
            texture = null;  
        }  
    }  
  
    static function checkASTCSupport():Bool {  
        if (astcSupported != null) return astcSupported;  
  
        #if (android || ios)  
        var extensions = GL.getSupportedExtensions();  
        if (extensions == null) {  
            astcSupported = false;  
            return false;  
        }  
        astcSupported = extensions.indexOf("GL_KHR_texture_compression_astc_ldr") >= 0 ||  
                        extensions.indexOf("GL_OES_texture_compression_astc") >= 0;  
        #else  
        astcSupported = false;  
        #end  
  
        trace('ASTC support: $astcSupported');  
        return astcSupported;  
    }  
  
    static function validateASTCHeader(data:Bytes):Bool {  
        if (data.length < 16) return false;  
        var magic = data.get(0) | (data.get(1) << 8) | (data.get(2) << 16) | (data.get(3) << 24);  
        return magic == 0x5CA1AB13;  
    }  
  
    static function readASTCDimensions(data:Bytes):{width:Int, height:Int, blockWidth:Int, blockHeight:Int} {  
        var blockX = data.get(4);  
        var blockY = data.get(5);  
        var width = data.get(7) | (data.get(8) << 8) | (data.get(9) << 16);  
        var height = data.get(10) | (data.get(11) << 8) | (data.get(12) << 16);  
        return {width: width, height: height, blockWidth: blockX, blockHeight: blockY};  
    }  
  
    static function getASTCFormat(blockWidth:Int, blockHeight:Int):Int {  
        return switch [blockWidth, blockHeight] {  
            case [4, 4]: COMPRESSED_RGBA_ASTC_4x4_KHR;  
            case [5, 4]: COMPRESSED_RGBA_ASTC_5x4_KHR;  
            case [5, 5]: COMPRESSED_RGBA_ASTC_5x5_KHR;  
            case [6, 5]: COMPRESSED_RGBA_ASTC_6x5_KHR;  
            case [6, 6]: COMPRESSED_RGBA_ASTC_6x6_KHR;  
            case [8, 5]: COMPRESSED_RGBA_ASTC_8x5_KHR;  
            case [8, 6]: COMPRESSED_RGBA_ASTC_8x6_KHR;  
            case [8, 8]: COMPRESSED_RGBA_ASTC_8x8_KHR;  
            case [10, 5]: COMPRESSED_RGBA_ASTC_10x5_KHR;  
            case [10, 6]: COMPRESSED_RGBA_ASTC_10x6_KHR;  
            case [10, 8]: COMPRESSED_RGBA_ASTC_10x8_KHR;  
            case [10, 10]: COMPRESSED_RGBA_ASTC_10x10_KHR;  
            case [12, 10]: COMPRESSED_RGBA_ASTC_12x10_KHR;  
            case [12, 12]: COMPRESSED_RGBA_ASTC_12x12_KHR;  
            default: throw 'Unsupported ASTC block size: ${blockWidth}x${blockHeight}';  
        }  
    }  
}