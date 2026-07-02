BLT._http_request_id = BLT._http_request_id or 0

local function normalize_http_url(url)
	if type(url) ~= "string" then
		return url
	end

	return url:gsub("^https?://www%.dropbox%.com/", "https://dl.dropboxusercontent.com/")
		:gsub("^https?://dropbox%.com/", "https://dl.dropboxusercontent.com/")
end

function BLT:HttpGet(url, clbk, progress_clbk)
	url = normalize_http_url(url)

	if Distribution and type(Distribution.make_http_request) == "function" then
		self._http_request_id = self._http_request_id + 1
		local http_id = self._http_request_id

		Distribution:make_http_request("GET", url, function(error_code, status_code, response_body)
			status_code = tonumber(status_code) or 0
			local ok = status_code >= 200 and status_code < 400
			local body = response_body or ""

			if progress_clbk and ok then
				progress_clbk(http_id, #body, #body)
			end

			clbk(body, http_id, {
				statusCode = status_code,
				querySucceeded = ok,
				url = url,
				headers = {},
			})
		end, {})

		return http_id
	end

	return dohttpreq(url, clbk, progress_clbk)
end
