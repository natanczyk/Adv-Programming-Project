
# Provides functions to test the exception handling
#module TestFunctionProvider

    #export  DivisionByZero, LineEndLimit, reciprocal_error, reciprocal_restart, reciprocal_signal, mystery, infinity, print_line

    #include("Exceptional.jl")
    #using .ExceptionHandling

    # Define custom exception-types
    struct DivisionByZero <: Exception end
    struct LineEndLimit <: Exception end

    reciprocal_error(x) =
        x == 0 ?
            error(DivisionByZero()) :
            1/x

    reciprocal_signal(x) =
        x == 0 ?
            signal(DivisionByZero()) :
            1/x

    reciprocal_restart(value) =
        with_restart(:return_zero => ()->0,
                    :return_value => identity,
                    :retry_using => reciprocal_restart) do
            value == 0 ?
                error(DivisionByZero()) :
                1/value
        end

    infinity() =
        with_restart(:just_do_it => ()->1/0) do
            reciprocal_error(0)
        end

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
#end





#module ExceptionHandlingTests

    #include("Exceptional.jl")
    #using Main.ExceptionHandling, .TestFunctionProvider, Test
    using Test

    @testset "Error Testset" begin
        @test           reciprocal_error(42) == 1/42
        @test_throws    DivisionByZero reciprocal_error(0)
    end

    @testset "Signal Testset" begin
        @test   isnothing(reciprocal_signal(0))

        # Signal detected
        @test_logs (:info, "LineEndLimit detected") handling(LineEndLimit => (c)->@info "LineEndLimit detected") do
                                                        print_line("Hello, everybody!!")
                                                    end
    end

    @testset "Handling Testset" begin
        # Dont exit after first handler (I saw a division by zero)
        @test_logs (:info,"I saw it too")    handling(DivisionByZero =>
                                                    (c)->@info "I saw it too") do
                                                handling(DivisionByZero =>
                                                        (c)->println("I saw a division by zero")) do
                                                    reciprocal_signal(0)
                                                end
                                            end
        
        # Same behavior for parent type: Exception
        @test_logs (:info,"I saw it too")    handling(Exception =>
                                            (c)->@info "I saw it too") do
                                        handling(Exception =>
                                                (c)->println("I saw a division by zero")) do
                                            reciprocal_signal(0)
                                        end
                                    end
    end



    @testset "Restart Testset" begin
        @test   handling(DivisionByZero => (c)->invoke_restart(:return_zero)) do
                    reciprocal_restart(0)
                end == 0

        @test   handling(DivisionByZero => (c)->invoke_restart(:return_value, 42)) do
                    reciprocal_restart(0) == 42
                end

        @test   handling(DivisionByZero => (c)->invoke_restart(:retry_using, 99)) do
                    reciprocal_restart(0) == reciprocal_restart(99)
                end
    end



    @testset "Escape Testset" begin
        @test mystery(0) == 3
        @test mystery(1) == 2
        @test mystery(2) == 4

        # Escape with "Done"
        @test   to_escape() do exit
                    handling(DivisionByZero =>
                        (c)->(println("I saw it too"); exit("Done"))) do
                            handling(DivisionByZero =>
                                (c)->println("I saw a division by zero")) do
                                    reciprocal_error(0)
                            end
                    end
                end == "Done"
        
        # Escape after second handler(I saw it too)
        @test_logs (:info,"I saw it too")   to_escape() do exit
                                                handling(DivisionByZero =>
                                                    (c)->(@info "I saw it too"; exit("Done"))) do
                                                        handling(DivisionByZero =>
                                                            (c)->println("I saw a division by zero")) do
                                                                reciprocal_error(0)
                                                        end
                                                end
                                            end

        # Escape after first handler(I saw a division by zero)
        @test_logs (:info,"I saw a division by zero")   to_escape() do exit
                                                            handling(DivisionByZero =>
                                                                (c)->println("I saw it too")) do
                                                                    handling(DivisionByZero =>
                                                                        (c)->(@info "I saw a division by zero";
                                                                            exit("Done"))) do
                                                                                reciprocal_error(0)
                                                                    end
                                                            end
                                                        end
    end



    @testset "Available Restart Testset" begin
        # No restart available => throw error
        @test_throws DivisionByZero handling(DivisionByZero =>
                    (c)-> for restart in (:return_one, :return_zero, :die_horribly)
                        if available_restart(restart)
                            invoke_restart(restart)
                        end
                    end) do
                    reciprocal_error(0)
                end

        @test_throws DivisionByZero handling(DivisionByZero =>
                (c)-> for restart in (:return_one, :return_zero, :die_horribly)
                    if available_restart(restart)
                        invoke_restart(restart)
                    end
                end) do
                reciprocal_error(0)
            end
    end
#end