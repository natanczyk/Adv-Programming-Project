#                            Test
#--------------------------------------------------------------------------------------------

reciprocal(x) =
    x == 0 ?
        error(DivisionByZero()) :
        1/x

handling(DivisionByZero => (c)->println("I saw it too")) do 
    handling(DivisionByZero => (c)->println("I saw a division by zero")) do
        reciprocal(0)
    end
end

handling(DivisionByZero => (c)->invoke_restart(:return_zero)) do
    reciprocal(0)
end


reciprocal2(value) =
    with_restart(:return_zero => ()->0,
            :return_value => identity,
            :retry_using => reciprocal2) do
        value == 0 ?
            error(DivisionByZero()) :
            1/value
    end

handling(DivisionByZero => (c)->invoke_restart(:return_zero)) do
    reciprocal2(0)
end


to_escape() do exit
    handling(DivisionByZero =>
    (c)->(println("I saw it too"); exit("Done"))) do
        handling(DivisionByZero =>
        (c)->println("I saw a division by zero")) do
        reciprocal(0)
        end
    end
end

to_escape() do exit
    handling(DivisionByZero =>
    (c)->println("I saw it too")) do
        handling(DivisionByZero =>
        (c)->(println("I saw a division by zero"); exit("Done"))) do
            reciprocal(0)
        end
    end
end

mystery(n) =
    1 +
    to_escape() do outer
        1 +
        to_escape() do inner
            1 +
            if n == 0
                inner(1)
            elseif n == 1
                outer(1)
            else
            1
            end
        end
    end

mystery(0)
mystery(1)
mystery(2)

print_line(str, line_end=10) =
    let col = 0
    for c in str
        print(c)
        col += 1
            if col == line_end
                signal(Exception())
                col = 0
            end
        end
    end

print_line("Hi, everybody! How are you feeling today?")

handling(Exception) => (c) -> println("signal") do 
    print_line("Hi, everybody! How are you feeling today?")
end