local H = {count=0,failed=0}
function H.test(name,fn)
    local ok,err=xpcall(fn,debug.traceback)
    H.count=H.count+1
    if ok then print("ok "..H.count.." - "..name)
    else H.failed=H.failed+1; print("not ok "..H.count.." - "..name.."\n"..err) end
end
function H.eq(a,b)
    assert(a==b,"expected "..tostring(b)..", got "..tostring(a))
end
function H.finish()
    print(string.format("RESULT: %d passed, %d failed, %d total",H.count-H.failed,H.failed,H.count))
    if H.failed>0 then os.exit(1) end
end
return H
