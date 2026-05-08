local TestSystem = require(game.ServerStorage.TestSystem)

local tester = TestSystem.new()

-- Основные математические операции
tester:describe("Математические операции", function()
    it("должна корректно складывать числа", function()
        expect(2 + 2).toEqual(4)
    end)
    
    it("должна корректно умножать числа", function()
        expect(3 * 5).toEqual(15)
    end)
    
    it("должна возвращать true для верных сравнений", function()
        expect(10 > 5).toBeTrue()
    end)
    
    it("должна проверять больше ли число", function()
        expect(10).toBeGreaterThan(5)
    end)
    
    it("должна проверять меньше ли число", function()
        expect(3).toBeLessThan(5)
    end)
    
    it("должна проверять тип числа", function()
        expect(42).toBeType("number")
    end)
    
    it("должна проверять приблизительное равенство", function()
        expect(0.1 + 0.2).toBeCloseTo(0.3, 0.0001)
    end)
end)

-- Работа со строками
tester:describe("Работа со строками", function()
    it("должна корректно объединять строки", function()
        expect("Hello" .. " " .. "World").toEqual("Hello World")
    end)
    
    it("должна возвращать длину строки", function()
        expect(("Roblox"):len()).toEqual(6)
    end)
    
    it("должна проверять тип строки", function()
        expect("text").toBeType("string")
    end)
    
    it("должна проверять наличие подстроки", function()
        expect("Hello World").toContain("Hello")
    end)
    
    it("должна проверять длину строки через toHaveLength", function()
        expect("Roblox").toHaveLength(6)
    end)
end)

-- Работа с таблицами
tester:describe("Работа с таблицами", function()
    it("должна проверять тип таблицы", function()
        expect({1, 2, 3}).toBeType("table")
    end)
    
    it("должна проверять наличие элемента в таблице", function()
        expect({1, 2, 3, 4, 5}).toContain(3)
    end)
    
    it("должна проверять длину таблицы", function()
        expect({1, 2, 3}).toHaveLength(3)
    end)
    
    it("должна проверять сложные структуры", function()
        local table = {"apple", "banana", "cherry"}
        expect(table).toBeType("table")
        expect(table).toContain("banana")
        expect(table).toHaveLength(3)
    end)
end)

-- Специальные случаи
tester:describe("Специальные случаи", function()
    it("должна работать с nil", function()
        expect(nil).toBeNil()
    end)
    
    it("должна работать с булевыми значениями", function()
        expect(true).toBeTrue()
        expect(false).toBeFalse()
    end)
    
    it("должна проверять не nil значения", function()
        expect("value").toBeNotNil()
    end)
end)

-- Запускаем все тесты
local results = tester:runAll()