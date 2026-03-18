import json

def run_backtest(script_content: str, prompt: str) -> str:
    # Stub for the actual vectorbt backtesting logic
    # In a real scenario, this would generate data, pass it to a vectorbt pipeline,
    # run the strategy logic, and return metrics.
    
    mock_metrics = {
        "Total Return": "12.5%",
        "Max Drawdown": "-5.2%",
        "Win Rate": "55%",
        "Sharpe Ratio": "1.2",
        "Total Trades": 45
    }
    
    return json.dumps(mock_metrics)
