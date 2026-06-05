import random
import httpx
import logging

logger = logging.getLogger(__name__)

class CerebrasManager:
    def __init__(self):
        self.api_keys = [
            "csk-w5ewfe5ym9dxxxrnxtw6m38d8vyv6rthcff8xptxm43dhpn6",
            "csk-p489t6vtm6etft3yjt5jpc4vjdmc5jtk58nxn5jy9nn6nkh2",
            "csk-p5cc4dfjh438jr2cff4rr36y6ndm395rc2335v6p4n2en286",
            "csk-e2jxpn326w432mrdrv8ehmrd25x5tjx8fdk3j34w88pr2emd",
            "csk-khdxd2mjx2pr54jk2vkjehkmnm956dmvecjpc5kwhfnm2mm4",
            "csk-p8vjwv2mr5hm9t5cv28mnpdrchrmdrc9w355nft3xhdj2pe4",
            "csk-dhncvkv5yntpk254vtvktddvy6jn9wjk83pphy5jwy2wjptm",
            "csk-ymv9232w3n6npjmhkmretvxk39cjwwjecdtjkkymdrmkv2kt",
            "csk-9pwx82kv5xn53d8e29d3wy3yx99mw2wdw39kf8ynfd64t89p",
            "csk-5jcd89wcewjc53eww5ppjktcd9vr3nvkmtrw9r465dkkwh4r",
            "csk-yhdvd49e8pht4v4vdvjttveh5pmx32v3hrpjyry656wtjr3x",
            "csk-kvm35nemewcde9xhdjxp46rpcrdc5jhh4k95hp25p46vj5c5",
            "csk-vxr6hx33y689dxwnmpfptdkh99h9mhxr5yr4ytrrvxvptpjw",
            "csk-ywd5fthk8kt3mt42fcwt6cfv6ep6merpm264nrecn89ptyk2",
            "csk-hye2fcfndhcv9y3wefe6wmxmx4n86v6p48w8m8w8993c3j9m",
            "csk-cvcedt32h8pyttweej5wj9hfcxep4h5wtkp82ftwrtwyrnf5",
            "csk-jfyhjjcm9tvmc54et8243me3enhevrcdfxwp9p4exe6e6crc",
            "csk-d4jtdrykfvv44k9ee5jj525vm88pvtrtvv8cj48xpyjpj4c4",
            "csk-cp6j4njj95k28xhdrycp8n5kf83mkf8crccdtd3r8kwfnxxe",
            "csk-tjjmte4m9mjd33jp8jveerfv4mxcf9ncc9rtnepkrw2tcy23",
            "csk-fyf9hycr5vtr4y8833jjj238wj5ctvrt29n88fprt5f5hf88",
            "csk-f8p282p6tmdkdej5t99jyf654t8wrjwtvyntnd3txcjx25hh",
            "csk-p6w933cf3mx2kp8eche35524ytpex8jte2vc9e2p5jjnkx6p",
            "csk-fxf59fyhme2kmjyed4p4t94c5m5e635f36knpcn9rkdhvcnc",
            "csk-xd8vfkn342f6v2whp59rpf8etkwjfmjkdcp885jmyxx5vntk",
            "csk-fe96mec436d4ke2yyfjkkd96pe89jmwd82wnhexwj696c4th",
            "csk-hp23n4889fkefjx56y6tfxnknxepr4jxtptp8crmm4x9wejn",
            "csk-xk2nxheyc3fr9f6f8wwj3twk49y6y623pvdkx8mkjedf99w2",
            "csk-mytjhxrp3nmnk8kwdwem4yvx62j2fvmwr4tk6cfjkp4mmvxx",
            "csk-httk8me8mtrw244xf3fvf5kmrcf6tevydfx8my996m54nf8p",
            "csk-tt4vpyxk9vk2njwkfr9p6vfy6vfj4jy39fhk9rvjt34mpfnx",
            "csk-9e3cmd4kfdn6fyy5cm5pve9hdhwxd5jm8pd3h35xmvxj8688",
            "csk-4erc2hmn93nyvyy8yt2djj6rcf2ecm6cfkrcxwc9ey9xwmxh",
            "csk-34w48v4p9w6w5eenvhnrjj69vn22w6tvef2fpvjd25kkmp44",
            "csk-p6hhc8d4je384jt8rtn2ky93jd9wkpt54mkk9k429k6cr8hn",
            "csk-k4r3jchd4pfdyew5vchjvvd362wefpvjddjrjr9pjedf6my5",
            "csk-68r9cfmwjj949w24f2p669eny8xmmey4y5fwm4r8exwet2mf",
            "csk-hw8c4hfpnh5c3edhcvm8ejtypkjhjf9x4j2ydr4wxen2fynx",
            "csk-m652r8n5tnw3ew894k3yr56cmdkrdd486j5tmnkdyn69ykj5",
            "csk-erkryjwv9dypm533k9jjrf4mef5x58kvprr4td6mvt5fd4fd",
            "csk-tm83nfym4ttvcnm8wejrf46xcedjpcwp4jx3cxvdk9k3fv6x",
            "csk-j2y4cehvdk6kxxyh8dwvdkneedv3mkpmeh9ddktfw6jdke9f",
            "csk-9p9wr8h868kmf2hxncdvy9hen8xvntcdr849k3nj3v9eycxn",
            "csk-634tvx5xept3dp623d4w85kpydckjrd5wvtjppmr8xmdwjwd",
            "csk-4hn5n5jykj6n2rth55rxfe5cydr2kwv35544fxnn5n59w5rc",
            "csk-pw398yf39wjww66fmjwvxnfhf9p9rv8hmvcp2wx5k9wvec56",
            "csk-rr48wr6852frnkwrrmf23t8w8j8v42d5d2hf8964jcfevfd5",
            "csk-xw8yf36584y42265tm8nh5hktpr9yp5v96jxfh5ed29m96f6",
            "csk-jm49y452hr56vr4d82tmmhtk8v9fxh3m92e242d8396cwxxv",
            "csk-yv5nx6jmpm2t96txd69c2jjptdkvfvd9462dhc6ef2ve3c82",
            "csk-9mrk5vdywmx4fyhhmy4y35nnd9mh588ph5kdrmytcet4pmdn",
            "csk-r9r2tvx6nf2wekd4w2m2rf4hxd9pdk3yxc8d95xepcjfkwdk",
            "csk-fnpx2t298d2f5cj2ytjn5wkwjtntn5py6vk528fjxxh8rdn2",
            "csk-j9wwkhptrdrnxcmhx63wm5f85pd395h4enp4fe6v2kwvhtee",
            "csk-ktt9k699vj6hct6e8ehyw245pfxypc39v8jp64kjdvjvk3yc"
        ]

    def get_random_key(self):
        return random.choice(self.api_keys)

    async def generate_chat_response(self, messages: list, model="gpt-oss-120b"):
        key = self.get_random_key()
        headers = {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        data = {
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1024,
        }
        
        url = "https://api.cerebras.ai/v1/chat/completions"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(url, headers=headers, json=data, timeout=30.0)
                response.raise_for_status()
                result = response.json()
                return result["choices"][0]["message"]["content"]
            except Exception as e:
                logger.error(f"Error calling Cerebras API: {str(e)}")
                raise

cerebras_manager = CerebrasManager()
