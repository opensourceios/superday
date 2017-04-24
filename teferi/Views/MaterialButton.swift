import UIKit

class MaterialButton: UIButton {
    
    var tapView:UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup()
    {
        tapView = UIView(frame: self.bounds)
        tapView.backgroundColor = UIColor.white
        tapView.isHidden = true
        self.addSubview(tapView)
        
        self.addTarget(self, action: #selector(MaterialButton.touchDown(sender:withEvent:)), for: UIControlEvents.touchDown)
        self.addTarget(self, action: #selector(MaterialButton.touchUpInside(sender:withEvent:)), for: UIControlEvents.touchUpInside)
    }
    
    func touchDown(sender:UIButton, withEvent event:UIEvent)
    {
        guard let touch = event.allTouches?.first else { return }
        tapView.layer.removeAllAnimations()
        
        let location = touch.location(in: self)
        let radius = max(max(location.x, frame.width-location.x), max(location.y, frame.height-location.y))
        
        tapView.layer.cornerRadius = radius
        tapView.frame = CGRect(origin: CGPoint.zero, size: CGSize(width: radius*2, height: radius*2))
        tapView.center = location
        tapView.alpha = 0.0
        tapView.transform = CGAffineTransform.init(scaleX: 0, y: 0)

        tapView.isHidden = false

        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            options: .curveEaseOut,
            animations: { [unowned self] in
                self.tapView.alpha = 0.5
                self.tapView.transform = CGAffineTransform.identity
            })
    }
    
    func touchUpInside(sender:UIButton, withEvent event:UIEvent)
    {
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            options: .curveEaseOut,
            animations: { [unowned self] in
                self.tapView.alpha = 0.0
            },
            completion: { _ in
                self.tapView.isHidden = true
            })
    }
}
