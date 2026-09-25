let topZ = 0;
const stacked = window.matchMedia("(max-width: 700px)"); // same breakpoint as style.css
const windows = document.querySelectorAll(".window");
windows.forEach(el => dragElement(el));

// drop positions from dragging when the screen gets small enough to stack the windows
stacked.addEventListener('change', e => {
    if (e.matches) windows.forEach(el => el.style.top = el.style.left = "");
});

function dragElement(elmnt) {
    var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;

    elmnt.addEventListener('mousedown',  () => elmnt.style.zIndex = ++topZ);
    elmnt.addEventListener('touchstart', () => elmnt.style.zIndex = ++topZ);

    const titleEl = elmnt.querySelector(".window-title") || elmnt;
    ['mousedown', 'touchstart'].forEach(ev => titleEl.addEventListener(ev, dragMouseDown));

    function getCoords(e) {
        let x, y;

        if (e.targetTouches && e.targetTouches.length > 0) {
            x = e.targetTouches[0].clientX;
            y = e.targetTouches[0].clientY;
        } else {
            x = e.clientX;
            y = e.clientY;
        }
        return { x, y };
    }

    function dragMouseDown(e) {
        if (stacked.matches) return;
        e.preventDefault();
        const {x, y} = getCoords(e);
        pos3 = x;
        pos4 = y;
        document.addEventListener('mouseup',   closeDragElement);
        document.addEventListener('touchend',  closeDragElement);
        document.addEventListener('mousemove', elementDrag);
        document.addEventListener('touchmove', elementDrag);
    }

    function elementDrag(e) {
        e.preventDefault();
        const {x, y} = getCoords(e);
        pos1 = pos3 - x;
        pos2 = pos4 - y;
        pos3 = x;
        pos4 = y;
        var newTop  = elmnt.offsetTop  - pos2;
        var newLeft = elmnt.offsetLeft - pos1;
        newTop  = Math.max(0, Math.min(newTop,  window.innerHeight - elmnt.offsetHeight));
        newLeft = Math.max(0, Math.min(newLeft, window.innerWidth  - elmnt.offsetWidth));
        elmnt.style.top  = newTop  + "px";
        elmnt.style.left = newLeft + "px";
    }

    function closeDragElement() {
        document.removeEventListener('mouseup',   closeDragElement);
        document.removeEventListener('touchend',  closeDragElement);
        document.removeEventListener('mousemove', elementDrag);
        document.removeEventListener('touchmove', elementDrag);
    }
}

