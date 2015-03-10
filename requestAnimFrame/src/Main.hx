package;

import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.Lib;
import js.Browser;

/**
 * ...
 * @author 
 */

class Main 
{
	
	static function main() 
	{
		new Main();
	}
	
	var canvas:CanvasElement;
	var canvasContext:CanvasRenderingContext2D; 
	var drawCount = 0;
	
	public function new() {
		canvas = Browser.document.createCanvasElement();
		canvasContext = canvas.getContext2d();
		canvas.width = 100; 
		canvas.height = 100; 
		canvasContext.fillStyle = "blue";
		canvasContext.font = "bold 16px Arial";
		Browser.document.body.appendChild(canvas);
		this.requestAnimFrame = Browser.window.requestAnimationFrame;
		this.requestAnimFrame(redrawCanvas);   	
	}
	
	var requestAnimFrame:(Float->Bool)->Int;
	
	function redrawCanvas(float:Float) {
		canvasContext.clearRect(0, 0, 100, 100);
		canvasContext.fillText(Std.string(drawCount++), 10, 40);
		this.requestAnimFrame(redrawCanvas);
		return true;
	}	
}