.pragma library

function greeting() {
    var h = new Date().getHours();
    if (h >= 5 && h < 12) return "Bom dia";
    if (h >= 12 && h < 18) return "Boa tarde";
    return "Boa noite";
}

function dayOfWeekPortuguese(date) {
    var days = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"];
    return days[new Date(date).getDay()];
}

function getWeekStart(date) {
    var d = new Date(date);
    var day = d.getDay();
    d.setDate(d.getDate() - day);
    d.setHours(0, 0, 0, 0);
    return d;
}

function formatDateKey(date) {
    var d = new Date(date);
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
}

function daysInMonth(month, year) {
    return new Date(year, month + 1, 0).getDate();
}

function firstDayOfWeek(month, year) {
    return new Date(year, month, 1).getDay();
}

function monthName(month) {
    var names = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];
    return names[month];
}

function shortMonthName(month) {
    var names = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];
    return names[month];
}

function dayName(dayIndex) {
    var names = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
    return names[dayIndex];
}

function isToday(day, displayMonth, displayYear) {
    var now = new Date();
    return day === now.getDate() && displayMonth === now.getMonth() && displayYear === now.getFullYear();
}

function isTodayDate(date) {
    var d = new Date(date);
    var now = new Date();
    return d.getDate() === now.getDate() && d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
}

function previousMonth(month, year) {
    var m = Number(month || 0);
    var y = Number(year || 0);
    if (m === 0) return { month: 11, year: y - 1 };
    return { month: m - 1, year: y };
}

function nextMonth(month, year) {
    var m = Number(month || 0);
    var y = Number(year || 0);
    if (m === 11) return { month: 0, year: y + 1 };
    return { month: m + 1, year: y };
}

function shiftWeek(weekStartDate, deltaDays) {
    var d = new Date(weekStartDate);
    d.setDate(d.getDate() + Number(deltaDays || 0));
    return d;
}

function getWeekHeaderText(weekStartDate) {
    var start = new Date(weekStartDate);
    var endDate = new Date(start);
    endDate.setDate(endDate.getDate() + 6);
    if (start.getMonth() === endDate.getMonth()) {
        return start.getDate() + " - " + endDate.getDate() + " " + shortMonthName(start.getMonth());
    }
    return start.getDate() + " " + shortMonthName(start.getMonth()) + " - " + endDate.getDate() + " " + shortMonthName(endDate.getMonth());
}

function parseHourValue(timeText) {
    var raw = String(timeText || "").trim();
    if (raw === "") return -1;
    var parts = raw.split(":");
    if (parts.length < 1) return -1;
    var hour = Number(parts[0]);
    if (!isFinite(hour) || hour < 0 || hour > 23) return -1;
    return Math.floor(hour);
}

function timeSortValue(timeText) {
    var raw = String(timeText || "").trim();
    if (raw === "") return 24 * 60;
    var parts = raw.split(":");
    var hour = parseHourValue(raw);
    if (hour < 0) return 24 * 60;
    var minute = Number(parts.length > 1 ? parts[1] : "0");
    if (!isFinite(minute) || minute < 0 || minute > 59) minute = 0;
    return (hour * 60) + Math.floor(minute);
}

function selectedDateLabel(dateKey) {
    var key = String(dateKey || "").trim();
    var parts = key.split("-");
    if (parts.length !== 3) return key;
    var y = Number(parts[0]);
    var m = Number(parts[1]);
    var d = Number(parts[2]);
    if (!isFinite(y) || !isFinite(m) || !isFinite(d)) return key;
    var date = new Date(y, m - 1, d);
    if (date.getFullYear() !== y || (date.getMonth() + 1) !== m || date.getDate() !== d) return key;
    return Qt.formatDateTime(date, "ddd, dd/MM");
}

function formatStopwatchTime(secs) {
    var m = Math.floor(secs / 60);
    var s = Math.floor(secs % 60);
    var ms = Math.floor((secs * 10) % 10);
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s + "." + ms;
}

function formatTimerTime(secs) {
    var h = Math.floor(secs / 3600);
    var m = Math.floor((secs % 3600) / 60);
    var s = Math.floor(secs % 60);
    if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
}

function resolveNoteColor(noteColors, colorId, fallbackColor) {
    var colors = noteColors || [];
    var wanted = String(colorId || "default");
    for (var i = 0; i < colors.length; i++) {
        if (colors[i] && colors[i].id === wanted)
            return colors[i].color;
    }
    return fallbackColor;
}
