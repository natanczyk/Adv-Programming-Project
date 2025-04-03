#Error works
reciprocal(x) =
    x == 0 ?
        error(DivisionByZero()) :
        1/x
reciprocal(0) 

#Signaling DOES NOT WORK FOR OTHER Exception
print_line(str, line_end=10) =
    let col = 0
    for c in str
        print(c)
        col += 1
            if col == line_end
                signal(LineEndLimit())
                col = 0
            end
        end
    end

print_line("Hi, everybody! How are you feeling today?")

handling(Exception) => (c) -> println("signal") do 
    print_line("Hi, everybody! How are you feeling today?")
end

#Handling works       
handling(DivisionByZero => (c)->println("I saw it too")) do 
    handling(DivisionByZero => (c)->println("I saw a division by zero")) do
        reciprocal(0)
    end
end

#To escape works
to_escape() do exit
    handling(DivisionByZero =>
    (c)->(println("I saw it too"); exit("Done"))) do
        handling(DivisionByZero =>
        (c)->println("I saw a division by zero")) do
        reciprocal(0)
        end
    end
end

#Example 2 of to escape
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

mystery(0) #should return 3
mystery(1) #should return 2
mystery(2) #should return 4


#with restart DOES NOT YET WORK
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


