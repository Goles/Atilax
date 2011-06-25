return function(request)
    print("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n")
    print("<html><body><h1>Delegated Request Info</h1><ul>")

    for k, v in pairs(request) do
        if "table" == type(v) then
            print(string.format("<li><b>%s</b>:</li><ul>", k))
            for k, v in pairs(v) do
                print(string.format("<li><b>%s</b>: %s</li>", k, v))
            end
            print("</ul>")
        else
            print(string.format("<li><b>%s</b>: %s</li>",
                  k, tostring(v)))
        end
    end
    print("</ul></body></html>")
    return true
end
