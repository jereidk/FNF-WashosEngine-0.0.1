package backend.texture;  
  
import lime.graphics.opengl.GL;  
import openfl.display3D.textures.RectangleTexture;  
import openfl.display.BitmapData;  
import flixel.FlxG;  
  
import lime.utils.ArrayBufferView;  
import lime.utils.UInt8Array;
import sys.io.File;  
import haxe.io.Bytes;  
  
class ASTCTexture {
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
  
            if (this.width <= 0 || this.height <= 0)   
                throw 'Invalid ASTC dimensions: ${this.width}x${this.height}';  
  
            var context = FlxG.stage.context3D;  
            this.texture = context.createRectangleTexture(width, height, BGRA, false);  
  
            @:privateAccess  
            var glTexture:lime.graphics.opengl.GLTexture = texture.__textureID;  
  
            var astcData:Bytes = data.sub(16, data.length - 16);  
            
            var buffer:UInt8Array = new UInt8Array(astcData.length);  
            for (i in 0...astcData.length) {  
                buffer[i] = astcData.get(i);  
            }  
  
            GL.bindTexture(GL.TEXTURE_2D, glTexture);  
            GL.compressedTexImage2D(  
                GL.TEXTURE_2D,  
                0,  
                getASTCFormat(blockWidth, blockHeight),  
                width,  
                height,  
                0,  
                astcData.length,  
                buffer  
            );  
  
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);  
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);  
            GL.bindTexture(GL.TEXTURE_2D, null);  
        }  
        catch(e:Dynamic) {  
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
	    astcSupported = false;
	    try {
	        var exts = GL.getSupportedExtensions();
	        if (exts == null) return false;
	        for (ext in exts) {
	            var e = ext.toLowerCase();
	            if (e.indexOf("texture_compression_astc") != -1 || e.indexOf("astc") != -1) {
	                astcSupported = true;
	                break;
	            }
	        }
	    } catch (err:Dynamic) {
	        trace('ASTC check error: $err');
	    }
	    return astcSupported;
	}
  
    static function validateASTCHeader(data:Bytes):Bool {  
        if (data.length < 16) return false;  
        var magic:Int = data.getInt32(0);  
        return magic == 0x5CA1AB13;  
    }  
  
    static function readASTCDimensions(data:Bytes):{width:Int, height:Int, blockWidth:Int, blockHeight:Int} {  
        var blockWidth:Int = data.get(4);  
        var blockHeight:Int = data.get(5);  
        var blockDepth:Int = data.get(6);  
          
        var width:Int = data.get(7) | (data.get(8) << 8) | (data.get(9) << 16);  
        var height:Int = data.get(10) | (data.get(11) << 8) | (data.get(12) << 16);  
          
        return {  
            width: width,  
            height: height,  
            blockWidth: blockWidth,  
            blockHeight: blockHeight  
        };  
    }  
  
    static function getASTCFormat(blockWidth:Int, blockHeight:Int):Int {  
        return switch([blockWidth, blockHeight]) {  
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