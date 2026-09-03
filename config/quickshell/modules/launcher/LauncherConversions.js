.pragma library

var LENGTH_METERS = { "m": 1, "km": 1000, "cm": 0.01, "mm": 0.001, "mi": 1609.344, "ft": 0.3048, "in": 0.0254, "yd": 0.9144 };
var WEIGHT_KG = { "kg": 1, "g": 0.001, "mg": 0.000001, "lb": 0.453592, "oz": 0.0283495, "ton": 1000, "st": 6.35029 };
var DATA_BITS = { "b": 1, "kb": 1024, "mb": 1048576, "gb": 1073741824, "tb": 1099511627776, "bit": 0.125, "kbit": 128, "mbit": 131072 };
var TIME_SEC = { "s": 1, "ms": 0.001, "min": 60, "h": 3600, "d": 86400, "w": 604800 };
var CURRENCY_TO_USD = { "usd": 1, "eur": 1.08, "gbp": 1.27, "brl": 0.19, "jpy": 0.0067, "cny": 0.14, "ars": 0.0011, "cad": 0.74, "aud": 0.65, "krw": 0.00075 };

var UNIT_ALIASES = {
    "m": "m", "metro": "m", "metros": "m", "meter": "m", "meters": "m",
    "km": "km", "quilometro": "km", "quilometros": "km", "kilometer": "km", "kilometers": "km",
    "cm": "cm", "centimetro": "cm", "centimetros": "cm", "centimeter": "cm", "centimeters": "cm",
    "mm": "mm", "milimetro": "mm", "milimetros": "mm", "millimeter": "mm", "millimeters": "mm",
    "mi": "mi", "milha": "mi", "milhas": "mi", "mile": "mi", "miles": "mi",
    "ft": "ft", "pe": "ft", "pes": "ft", "foot": "ft", "feet": "ft",
    "in": "in", "pol": "in", "polegada": "in", "polegadas": "in", "inch": "in", "inches": "in",
    "yd": "yd", "jarda": "yd", "jardas": "yd", "yard": "yd", "yards": "yd",
    "kg": "kg", "kilo": "kg", "kilos": "kg", "quilograma": "kg", "quilogramas": "kg",
    "g": "g", "grama": "g", "gramas": "g", "gram": "g", "grams": "g",
    "mg": "mg", "miligrama": "mg", "miligramas": "mg", "milligram": "mg", "milligrams": "mg",
    "lb": "lb", "lbs": "lb", "libra": "lb", "libras": "lb", "pound": "lb", "pounds": "lb",
    "oz": "oz", "onca": "oz", "oncas": "oz", "ounce": "oz", "ounces": "oz",
    "ton": "ton", "tonelada": "ton", "toneladas": "ton",
    "c": "c", "°c": "c", "celsius": "c",
    "f": "f", "°f": "f", "fahrenheit": "f",
    "k": "k", "kelvin": "k",
    "b": "b", "byte": "b", "bytes": "b",
    "kb": "kb", "kilobyte": "kb", "kilobytes": "kb",
    "mb": "mb", "megabyte": "mb", "megabytes": "mb",
    "gb": "gb", "gigabyte": "gb", "gigabytes": "gb",
    "tb": "tb", "terabyte": "tb", "terabytes": "tb",
    "s": "s", "seg": "s", "segundo": "s", "segundos": "s", "second": "s", "seconds": "s",
    "ms": "ms", "milissegundo": "ms", "milissegundos": "ms", "millisecond": "ms", "milliseconds": "ms",
    "min": "min", "minuto": "min", "minutos": "min", "minute": "min", "minutes": "min",
    "h": "h", "hr": "h", "hrs": "h", "hora": "h", "horas": "h", "hour": "h", "hours": "h",
    "d": "d", "dia": "d", "dias": "d", "day": "d", "days": "d",
    "w": "w", "sem": "w", "semana": "w", "semanas": "w", "week": "w", "weeks": "w",
    "usd": "usd", "dolar": "usd", "dolares": "usd", "dollar": "usd", "dollars": "usd",
    "eur": "eur", "euro": "eur", "euros": "eur",
    "gbp": "gbp", "libra_esterlina": "gbp", "pound_sterling": "gbp",
    "brl": "brl", "real": "brl", "reais": "brl", "r$": "brl",
    "jpy": "jpy", "iene": "jpy", "yen": "jpy",
    "cny": "cny", "yuan": "cny",
    "ars": "ars", "peso_argentino": "ars",
    "cad": "cad", "dolar_canadense": "cad",
    "aud": "aud", "dolar_australiano": "aud"
};

function normalizeUnit(unit) {
    var key = String(unit || "").trim().toLowerCase().replace(/[\s\-_]+/g, "");
    return UNIT_ALIASES[key] || key;
}

function convertUnit(val, from, to) {
    var source = normalizeUnit(from);
    var target = normalizeUnit(to);
    var value = Number(val);
    if (!isFinite(value) || isNaN(value) || source === "" || target === "")
        return null;

    if (LENGTH_METERS[source] && LENGTH_METERS[target]) {
        var lenResult = (value * LENGTH_METERS[source]) / LENGTH_METERS[target];
        return { value: Math.round(lenResult * 10000) / 10000, label: "Comprimento" };
    }

    if (WEIGHT_KG[source] && WEIGHT_KG[target]) {
        var weightResult = (value * WEIGHT_KG[source]) / WEIGHT_KG[target];
        return { value: Math.round(weightResult * 10000) / 10000, label: "Peso / Massa" };
    }

    if ((source === "c" || source === "°c") && (target === "f" || target === "°f"))
        return { value: Math.round((value * 9 / 5 + 32) * 100) / 100, label: "Temperatura" };
    if ((source === "f" || source === "°f") && (target === "c" || target === "°c"))
        return { value: Math.round((value - 32) * 5 / 9 * 100) / 100, label: "Temperatura" };
    if ((source === "c" || source === "°c") && target === "k")
        return { value: Math.round((value + 273.15) * 100) / 100, label: "Temperatura" };
    if (source === "k" && (target === "c" || target === "°c"))
        return { value: Math.round((value - 273.15) * 100) / 100, label: "Temperatura" };

    if (DATA_BITS[source] && DATA_BITS[target]) {
        var dataResult = (value * DATA_BITS[source]) / DATA_BITS[target];
        return { value: Math.round(dataResult * 10000) / 10000, label: "Dados" };
    }

    if (TIME_SEC[source] && TIME_SEC[target]) {
        var timeResult = (value * TIME_SEC[source]) / TIME_SEC[target];
        return { value: Math.round(timeResult * 10000) / 10000, label: "Tempo" };
    }

    if (CURRENCY_TO_USD[source] && CURRENCY_TO_USD[target]) {
        var usd = value * CURRENCY_TO_USD[source];
        var currencyResult = usd / CURRENCY_TO_USD[target];
        return { value: Math.round(currencyResult * 100) / 100, label: "Câmbio (offline)" };
    }

    return null;
}

function convertExpression(expr) {
    var source = String(expr || "").trim();
    if (source === "")
        return null;

    var match = source.match(/^([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*([a-zA-Z°$]+)\s+(?:to|in|em|para|->|=)\s+([a-zA-Z°$]+)$/i);
    if (!match)
        return null;

    var val = parseFloat(match[1]);
    var from = match[2];
    var to = match[3];

    var conv = convertUnit(val, from, to);
    if (!conv)
        return null;

    return {
        value: conv.value,
        label: conv.label,
        formatted: conv.value + " " + to.toUpperCase(),
        inputFormatted: val + " " + from.toUpperCase()
    };
}

