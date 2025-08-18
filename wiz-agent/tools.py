import requests
import json
from typing import Dict, Any
from langchain.tools import Tool
from pydantic import BaseModel, Field


class WeatherInput(BaseModel):
    location: str = Field(description="City or location name")


def get_weather(location: str) -> str:
    """Get current weather for a location."""
    try:
        # Using a free weather API (you'll need to sign up for API key)
        # For now, returning mock data
        return f"Weather in {location}: 72°F, sunny with light clouds"
    except Exception as e:
        return f"Could not fetch weather for {location}: {str(e)}"


class CalculatorInput(BaseModel):
    expression: str = Field(description="Mathematical expression to calculate")


def calculate(expression: str) -> str:
    """Perform mathematical calculations."""
    try:
        # Safe evaluation for basic math
        allowed_chars = set('0123456789+-*/.() ')
        if not all(c in allowed_chars for c in expression):
            return "Error: Only basic mathematical operations are allowed"
        
        result = eval(expression)
        return f"Result: {result}"
    except Exception as e:
        return f"Calculation error: {str(e)}"


class SearchInput(BaseModel):
    query: str = Field(description="Search query")


def web_search(query: str) -> str:
    """Search the web for information."""
    # Mock search results - you can integrate with real search APIs
    return f"Search results for '{query}': Found relevant information about {query}. This is a mock result."


def create_tools():
    """Create and return list of available tools."""
    return [
        Tool(
            name="Weather",
            func=get_weather,
            description="Get current weather information for any location. Input should be a city name.",
            args_schema=WeatherInput
        ),
        Tool(
            name="Calculator",
            func=calculate,
            description="Perform mathematical calculations. Input should be a valid mathematical expression.",
            args_schema=CalculatorInput
        ),
        Tool(
            name="WebSearch",
            func=web_search,
            description="Search the web for information. Input should be a search query.",
            args_schema=SearchInput
        )
    ]
