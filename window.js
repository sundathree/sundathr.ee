dragElement(document.querySelector(".window"));

function dragElement(elmnt) {
    var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;

    elmnt.style.left = (window.innerWidth  / 2 - elmnt.offsetWidth  / 2) + "px";
    elmnt.style.top  = (window.innerHeight / 2 - elmnt.offsetHeight / 2) + "px";

    if (elmnt.querySelector(".window-title")) {
        elmnt.querySelector(".window-title").onmousedown = dragMouseDown;
    } else {
        elmnt.onmousedown = dragMouseDown;
    }

    function dragMouseDown(e) {
        e = e || window;
        e.preventDefault();
        pos3 = e.clientX;
        pos4 = e.clientY;
        document.onmouseup = closeDragElement;
        document.onmousemove = elementDrag;
    }

    function elementDrag(e) {
        e = e || window;
        e.preventDefault();
        pos1 = pos3 - e.clientX;
        pos2 = pos4 - e.clientY;
        pos3 = e.clientX;
        pos4 = e.clientY;
        elmnt.style.top = (elmnt.offsetTop - pos2) + "px";
        elmnt.style.left = (elmnt.offsetLeft - pos1) + "px";
        // TODO: clamp the window position
        // var newTop  = elmnt.offsetTop  - pos2;
        // var newLeft = elmnt.offsetLeft - pos1;
        // elmnt.style.top  = newTop  + "px";
        // elmnt.style.left = newLeft + "px";
    }

    function closeDragElement() {
        document.onmouseup = null;
        document.onmousemove = null;
    }
}
