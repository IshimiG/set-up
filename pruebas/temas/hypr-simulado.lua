-- Un Hyprland de mentira para leer lo que hace hyprland.lua sin Hyprland.
--
--   lua hypr-simulado.lua <hyprland.lua> [aberracion]
--
-- Ejecuta el fichero con un `hl` falso que apunta cada llamada y saca, una por
-- línea y en orden estable:
--   config <clave.con.puntos> = <valor>   lo que queda de juntar todos los
--                                         hl.config (el último gana)
--   <hl.función>(<argumentos>)            el resto de llamadas: binds, reglas,
--                                         animaciones, exec_cmd…
-- Las funciones que hl.on registra se ejecutan al momento, con su evento
-- delante. Con "aberracion", al final llama a escritorio.aberracion(1), (2) y
-- (0), como hace scripts/aberracion.sh con hyprctl eval, y saca el borde que
-- queda tras cada una.
--
-- El tema lo lee hyprland.lua de $XDG_STATE_HOME, como siempre: la prueba le
-- da uno de mentira.

local fichero, extra = arg[1], arg[2]

local function ordenadas(t)
	local claves = {}
	for k in pairs(t) do
		claves[#claves + 1] = k
	end
	table.sort(claves, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return claves
end

local serie

-- Un valor como texto, igual siempre para el mismo valor.
serie = function(v)
	local tipo = type(v)
	if tipo == "string" then
		return string.format("%q", v)
	elseif tipo == "number" then
		if math.type(v) == "integer" then
			return string.format("%d", v)
		end
		return string.format("%.6g", v)
	elseif tipo == "table" then
		local meta = getmetatable(v)
		if meta and meta.texto then
			return meta.texto
		end
		local partes = {}
		for _, k in ipairs(ordenadas(v)) do
			partes[#partes + 1] = tostring(k) .. "=" .. serie(v[k])
		end
		return "{" .. table.concat(partes, ", ") .. "}"
	elseif tipo == "function" then
		return "<función>"
	end
	return tostring(v)
end

local llamadas = {}
local config = {}

-- Junta un hl.config en `config`, por claves con puntos. Las tablas de
-- colores de un borde (con `colors`) y las listas son un valor entero, no
-- más claves.
local function juntar(t, prefijo)
	for k, v in pairs(t) do
		local clave = prefijo == "" and k or (prefijo .. "." .. k)
		if type(v) == "table" and v.colors == nil and v[1] == nil then
			juntar(v, clave)
		else
			config[clave] = v
		end
	end
end

local proxy

-- `ruta` es el nombre (hl.dsp.window.close); `texto`, cómo se escribe el
-- valor si se pasa a otra llamada (hl.bind recibe lo que da hl.dsp.*).
proxy = function(ruta, texto)
	return setmetatable({}, {
		texto = texto or ruta,
		__index = function(_, k)
			return proxy(ruta .. "." .. k)
		end,
		__call = function(_, ...)
			local args = table.pack(...)
			local partes = {}
			for i = 1, args.n do
				partes[i] = serie(args[i])
			end
			local descripcion = ruta .. "(" .. table.concat(partes, ", ") .. ")"
			if ruta == "hl.config" then
				juntar(args[1], "")
			elseif ruta == "hl.on" then
				llamadas[#llamadas + 1] = descripcion
				args[2]()
				llamadas[#llamadas + 1] = "fin " .. serie(args[1])
			elseif not ruta:match("^hl%.dsp%.") then
				llamadas[#llamadas + 1] = descripcion
			end
			-- Lo que devuelve: un asa (hl.window_rule) o un dispatcher
			-- (hl.dsp.*), que sólo se escribe.
			return proxy(ruta .. "()", descripcion)
		end,
	})
end

hl = proxy("hl")

local ok, err = pcall(dofile, fichero)
if not ok then
	io.stderr:write("error al ejecutar " .. fichero .. ": " .. tostring(err) .. "\n")
	os.exit(1)
end

for _, k in ipairs(ordenadas(config)) do
	print("config " .. k .. " = " .. serie(config[k]))
end
for _, l in ipairs(llamadas) do
	print(l)
end

if extra == "aberracion" then
	if type(escritorio) ~= "table" or type(escritorio.aberracion) ~= "function" then
		print("sin escritorio.aberracion")
		os.exit(1)
	end
	for _, paso in ipairs({ 1, 2, 3, 0 }) do
		escritorio.aberracion(paso)
		print("aberracion(" .. paso .. ") " .. serie(config["general.col.active_border"]))
	end
end
