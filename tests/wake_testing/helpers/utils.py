

class EvmMath():
    
    def parse_eth(value) -> int:
        return int(value * 10 ** 18)
    
    def parse_decimals(value: any, decimals: int) -> int:
        return int(value * 10 ** decimals)
