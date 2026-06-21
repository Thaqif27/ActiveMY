def categorize_event(title: str) -> str:
    t = title.lower()
    
    cycling_keywords = ['cycling', 'bike', 'cycle', 'ride', 'pedal', 'mtb', 'bmx', 'tour', 'velodrome', 'bicycle', 'basikal', 'kayuh']
    if any(w in t for w in cycling_keywords):
        return 'cycling'
        
    hiking_keywords = ['hiking', 'trek', 'trail', 'climb', 'mountain', 'camp', 'hike', 'gunung', 'bukit', 'expedition', 'nature', 'mendaki']
    if any(w in t for w in hiking_keywords):
        return 'hiking'
        
    return 'running'
