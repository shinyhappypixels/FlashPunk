package net.flashpunk.graphics 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Sprite;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import net.flashpunk.*;
	
	/**
	 * Performance-optimized non-animated image. Can be drawn to the screen with transformations.
	 */
	public class Image extends Graphic
	{
		/**
		 * Rotation of the image, in degrees.
		 */
		public var angle:Number = 0;
		
		/**
		 * Scale of the image, affects both x and y scale.
		 */
		public var scale:Number = 1;
		
		/**
		 * X scale of the image.
		 */
		public var scaleX:Number = 1;
		
		/**
		 * Y scale of the image.
		 */
		public var scaleY:Number = 1;
		
		/**
		 * X origin of the image, determines transformation point.
		 */
		public var originX:Number = 0;
		
		/**
		 * Y origin of the image, determines transformation point.
		 */
		public var originY:Number = 0;
		
		/**
		 * Optional blend mode to use when drawing this image.
		 * Use constants from the flash.display.BlendMode class.
		 */
		public var blend:String;
		
		/**
		 * If the image should be drawn transformed with pixel smoothing.
		 * This will affect drawing performance, but look less pixelly.
		 */
		public var smooth:Boolean;
		
		/**
		 * Color tint modes
		 */
		public static const TINTING_MULTIPLY:Number = 0.0;
		public static const TINTING_COLORIZE:Number = 1.0;
		
		/**
		 * Constructor.
		 * @param	source		Source image.
		 * @param	clipRect	Optional rectangle defining area of the source image to draw.
		 */
		public function Image(source:*, clipRect:Rectangle = null) 
		{
			if (source is Class)
			{
				_source = FP.getBitmap(source);
				_class = String(source);
			}
			else if (source is BitmapData) _source = source;
			if (!_source) throw new Error("Invalid source image.");
			_sourceRect = _source.rect;
			if (clipRect)
			{
				if (!clipRect.width) clipRect.width = _sourceRect.width;
				if (!clipRect.height) clipRect.height = _sourceRect.height;
				_sourceRect = clipRect;
			}
			createBuffer();
			updateBuffer();
		}
		
		/** @private Creates the buffer. */
		protected function createBuffer():void
		{
			if (_buffer) {
				_buffer.dispose();
				_buffer = null;
			}
			_buffer = new BitmapData(_sourceRect.width, _sourceRect.height, true, 0);
			_bufferRect = _buffer.rect;
			_bitmap.bitmapData = _buffer;
		}
		
		/** Update the DrawMask image, if we have one. */
		override public function update():void {
			if (_drawMask !== null && _drawMask.active) {
				_drawMask.update();
			}
		}
		
		/** @private Renders the image. */
		override public function render(target:BitmapData, point:Point, camera:Point):void
		{
			// quit if no graphic is assigned
			if (!_buffer) return;
			
			// determine drawing location
			_point.x = point.x + x - originX - camera.x * scrollX;
			_point.y = point.y + y - originY - camera.y * scrollY;
			
			// render without transformation
			if (angle == 0 && scaleX * scale == 1 && scaleY * scale == 1 && !blend)
			{
				if (_drawMask == null) {
					target.copyPixels(_buffer, _bufferRect, _point, null, null, true);
				}
				else {
					target.copyPixels(_buffer, _bufferRect, _point, _drawMaskBmp.bitmapData, FP.zero, true);
				}
				return;
			}
			
			// render with transformation
			_matrix.b = _matrix.c = 0;
			_matrix.a = scaleX * scale;
			_matrix.d = scaleY * scale;
			_matrix.tx = -originX * _matrix.a;
			_matrix.ty = -originY * _matrix.d;
			if (angle != 0) _matrix.rotate(angle * FP.RAD);
			_matrix.tx += originX + _point.x;
			_matrix.ty += originY + _point.y;
			_bitmap.smoothing = smooth;
			
			if (_drawMaskBmp != null) {
				target.draw(_drawMaskSprite, _matrix, null, blend, null, smooth);
			}
			else {
				target.draw(_bitmap, _matrix, null, blend, null, smooth);
			}
			
			
		}
		
		/**
		 * Creates a new rectangle Image.
		 * @param	width		Width of the rectangle.
		 * @param	height		Height of the rectangle.
		 * @param	color		Color of the rectangle.
		 * @return	A new Image object.
		 */
		public static function createRect(width:uint, height:uint, color:uint = 0xFFFFFF, alpha:Number = 1):Image
		{
			var source:BitmapData = new BitmapData(width, height, true, 0xFFFFFFFF);
			
			var image:Image = new Image(source);
			
			image.color = color;
			image.alpha = alpha;
			
			return image;
		}
		
		/**
		 * Creates a new circle Image.
		 * @param	radius		Radius of the circle.
		 * @param	color		Color of the circle.
		 * @param	alpha		Alpha of the circle.
		 * @return	A new Image object.
		 */
		public static function createCircle(radius:uint, color:uint = 0xFFFFFF, alpha:Number = 1):Image
		{
			FP.sprite.graphics.clear();
			FP.sprite.graphics.beginFill(0xFFFFFF);
			FP.sprite.graphics.drawCircle(radius, radius, radius);
			var data:BitmapData = new BitmapData(radius * 2, radius * 2, true, 0);
			data.draw(FP.sprite);
			
			var image:Image = new Image(data);
			
			image.color = color;
			image.alpha = alpha;
			
			return image;
		}
		
		/**
		 * Updates the image buffer.
		 */
		public function updateBuffer(clearBefore:Boolean = false):void
		{
			if (locked)
			{
				_needsUpdate = true;
				if (clearBefore) _needsClear = true;
				return;
			}
			if (!_source) return;
			if (clearBefore) _buffer.fillRect(_bufferRect, 0);
			_buffer.copyPixels(_source, _sourceRect, FP.zero);
			if (_tint) _buffer.colorTransform(_bufferRect, _tint);
		}
		
		/**
		 * Clears the image buffer.
		 */
		public function clear():void
		{
			_buffer.fillRect(_bufferRect, 0);
		}
		
		/**
		 * Change the opacity of the Image, a value from 0 to 1.
		 */
		public function get alpha():Number { return _alpha; }
		public function set alpha(value:Number):void
		{
			value = value < 0 ? 0 : (value > 1 ? 1 : value);
			if (_alpha == value) return;
			_alpha = value;
			updateColorTransform();
		}
		
		/**
		 * The tinted color of the Image. Use 0xFFFFFF to draw the Image normally with the default blending mode.
		 */
		public function get color():uint { return _color; }
		public function set color(value:uint):void
		{
			value &= 0xFFFFFF;
			if (_color == value) return;
			_color = value;
			updateColorTransform();
		}
		
		/**
		 * The amount the image will be tinted, suggested values from 0 to 1. 0 Means no change, 1 is full color tint.
		 */
		public function get tinting():Number { return _tintFactor; }
		public function set tinting(value:Number):void
		{
			if (_tintFactor == value) return;
			_tintFactor = value;
			updateColorTransform();
		}
		
		/**
		 * The tint mode - multiply or colorize
		 */
		public function get tintMode():Number { return _tintMode; }
		public function set tintMode(value:Number):void
		{
			if (_tintMode == value) return;
			_tintMode = value;
			updateColorTransform();
		}
		
		/**
		 * Updates the color transform
		 */
		protected function updateColorTransform():void {
			if (_alpha == 1) {
				if (_tintFactor == 0) {
					_tint = null;
					return updateBuffer();
				}
				if ((_tintMode == TINTING_MULTIPLY) && (_color == 0xFFFFFF)) {
					_tint = null;
					return updateBuffer();
				}
			}
			_tint = _colorTransform;
			
			_tint.redMultiplier   = _tintMode * (1.0 - _tintFactor) + (1-_tintMode) * (_tintFactor * (Number(_color >> 16 & 0xFF) / 255 - 1) + 1);
			_tint.greenMultiplier = _tintMode * (1.0 - _tintFactor) + (1-_tintMode) * (_tintFactor * (Number(_color >> 8 & 0xFF) / 255 - 1) + 1);
			_tint.blueMultiplier  = _tintMode * (1.0 - _tintFactor) + (1-_tintMode) * (_tintFactor * (Number(_color & 0xFF) / 255 - 1) + 1);
			_tint.redOffset       = (_color >> 16 & 0xFF) * _tintFactor * _tintMode;
			_tint.greenOffset     = (_color >> 8 & 0xFF) * _tintFactor * _tintMode;
			_tint.blueOffset      = (_color & 0xFF) * _tintFactor * _tintMode;
			
			_tint.alphaMultiplier = _alpha;
			updateBuffer();
		}
		
		/**
		 * If you want to draw the Image horizontally flipped. This is
		 * faster than setting scaleX to -1 if your image isn't transformed.
		 */
		public function get flipped():Boolean { return _flipped; }
		public function set flipped(value:Boolean):void
		{
			if (_flipped == value) return;
			_flipped = value;
			var temp:BitmapData = _source;
			if (_flip)
			{
				_source = _flip;
				_flip = temp;
				updateBuffer();
			}
			if (_class && _flips[_class])
			{
				_source = _flips[_class];
				_flip = temp;
				updateBuffer();
			}
			_source = new BitmapData(_source.width, _source.height, true, 0);
			_flip = temp;
			FP.matrix.identity();
			FP.matrix.a = -1;
			FP.matrix.tx = _source.width;
			_source.draw(temp, FP.matrix);
			
			if (_class) _flips[_class] = _source;
			
			updateBuffer();
		}
		
		/**
		 * Centers the Image's originX/Y to its center.
		 */
		public function centerOrigin():void
		{
			originX = _bufferRect.width / 2;
			originY = _bufferRect.height / 2;
		}
		
		/**
		 * Centers the Image's originX/Y to its center.
		 */
		public function centerOO():void
		{
			centerOrigin();
		}
		
		/**
		 * Width of the image.
		 */
		public function get width():uint { return _bufferRect.width; }
		
		/**
		 * Height of the image.
		 */
		public function get height():uint { return _bufferRect.height; }
		
		/**
		 * The scaled width of the image.
		 */
		public function get scaledWidth():uint { return _bufferRect.width * scaleX * scale; }
		
		/**
		 * The scaled height of the image.
		 */
		public function get scaledHeight():uint { return _bufferRect.height * scaleY * scale; }
		
		/**
		 * Clipping rectangle for the image.
		 */
		public function get clipRect():Rectangle { return _sourceRect; }
		
		/** @protected Source BitmapData image. */
		protected function get source():BitmapData { return _source; }
		
		/**
		 * Lock the image, preventing updateBuffer() from being run until
		 * unlock() is called, for performance.
		 */
		public function lock():void
		{
			_locked = true;
		}
		
		/**
		 * Unlock the image. Any pending updates will be applied immediately.
		 */
		public function unlock():void
		{
			_locked = false;
			if (_needsUpdate) updateBuffer(_needsClear);
			_needsUpdate = _needsClear = false;
		}
		
		/**
		 * True if the image is locked.
		 */
		public function get locked():Boolean { return _locked; }
		
		/**
		 * Assigns another `Image` instance to be this one's drawing mask.
		 */
		public function set drawMask(img:Image):void {
			// Do nothing if it's the same mask
			if (img == _drawMask) {
				return;
			}
			
			if (_drawMask != null) {
				_drawMaskSprite.removeChild(_bitmap);
				_drawMaskSprite.removeChild(_drawMaskBmp);
			}
			
			if (img == null) {
				_bitmap.mask = null;
				_drawMask = null;
				_drawMaskBmp = null;
			}
			else {
				//_bitmap.cacheAsBitmap = true;
				_drawMask = img;
				_drawMaskBmp = img.assignAsMask(this);
				//_bitmap.opaqueBackground = 0xFFFF00FF;
				
				_drawMaskSprite.addChild(_bitmap);
				_drawMaskSprite.addChild(_drawMaskBmp);
				
				_bitmap.cacheAsBitmap = true;
				_drawMaskBmp.cacheAsBitmap = true;
				_drawMaskSprite.cacheAsBitmap = true;
				
				_bitmap.mask = _drawMaskBmp;

				/*
				_bitmap.x = 0;
				_drawMaskBmp.x = 0;
				_drawMaskSprite.x = 0;
				
				_bitmap.y = 0;
				_drawMaskBmp.y = 0;
				_drawMaskSprite.y = 0;
				*/
				
			}
		}
		
		/**
		 * Return the drawing mask.
		 */
		public function get drawMask():Image {
			return _drawMask;
		}
		
		/**
		 * Called when this image is set to be another's drawing mask
		 */
		public function assignAsMask(img:Image):Bitmap {
			//_bitmap.cacheAsBitmap = true;
			return _bitmap;
		}
		
		// Locking
		/** @private */ protected var _locked:Boolean = false;
		/** @private */ protected var _needsClear:Boolean = false;
		/** @private */ protected var _needsUpdate:Boolean = false;
		
		// Source and buffer information.
		/** @private */ protected var _source:BitmapData;
		/** @private */ protected var _sourceRect:Rectangle;
		/** @private */ protected var _buffer:BitmapData;
		/** @private */ protected var _bufferRect:Rectangle;
		/** @private */ protected var _bitmap:Bitmap = new Bitmap;
		
		// Color and alpha information.
		/** @private */ private var _alpha:Number = 1;
		/** @private */ private var _color:uint = 0x00FFFFFF;
		/** @private */ private var _tintFactor:Number = 1.0;
		/** @private */ private var _tintMode:Number = TINTING_MULTIPLY;
		/** @protected */ protected var _tint:ColorTransform;
		/** @private */ private var _colorTransform:ColorTransform = new ColorTransform;
		/** @private */ private var _matrix:Matrix = FP.matrix;
		
		// Flipped image information.
		/** @protected */ protected var _class:String;
		/** @protected */ protected var _flipped:Boolean;
		/** @protected */ protected var _flip:BitmapData;
		/** @protected */ protected static var _flips:Object = { };
		
		// DrawMask information
		/** @protected */ protected var _drawMask:Image = null;
		/** @protected */ protected var _drawMaskBmp:Bitmap = null;
		/** @protected */ protected var _drawMaskSprite:Sprite = new Sprite;
	}
}
