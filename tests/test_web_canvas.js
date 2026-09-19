// Checks the shipped shell's pixel budget without booting a browser or game save.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const shell = fs.readFileSync(path.join(__dirname, '../web/shell.html'), 'utf8');
const sizing = shell.match(/function getGameCanvasSize\([\s\S]*?\n}/);
assert.ok(sizing, 'shipped shell includes canvas sizing');
const context = vm.createContext({});
vm.runInContext(sizing[0], context);
let checks = 0;
for (const [width, height, dpr] of [[1280,800,1], [1280,800,2], [1920,1080,2], [3840,2160,2], [2560,1600,2], [960,600,1], [640,360,2], [390,844,3], [800,600,1.25]]) {
	const [w,h] = context.getGameCanvasSize(width,height,dpr);
	assert.ok(Number.isInteger(w) && Number.isInteger(h) && w > 0 && h > 0);
	assert.ok(w <= 3840 && h <= 2400 && w*h <= 8294400, 'bounded full-resolution UI canvas');
	assert.ok(Math.abs(w/h - width/height) < 2/h, 'resize preserves the window aspect ratio');
	assert.ok(w <= width*dpr && h <= height*dpr, 'never renders beyond native resolution');
	checks += 4;
}
for (const mode of ['balanced', 'smooth', 'crisp']) {
 const dimensions = context.getGameCanvasSize(1280,800,2,mode);
 assert.equal(dimensions[0],2560,'every mode keeps native Retina text');
 assert.equal(dimensions[1],1600,'3D settings cannot shrink UI');
 checks += 2;
}
for (const value of [NaN, Infinity, 0, -4]) {
	const dimensions = context.getGameCanvasSize(value,value,value);
	assert.ok(dimensions.every(n => Number.isInteger(n) && n > 0));
	checks++;
}
assert.match(fs.readFileSync(path.join(__dirname, '../export_presets.cfg'),'utf8'), /html\/canvas_resize_policy=0/);
console.log(`WEB CANVAS: ${checks + 1} checks passed`);
