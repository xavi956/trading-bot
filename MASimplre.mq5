//+------------------------------------------------------------------+
//|                              Media Móvil Simple AE Cobertura.mq5 |
//|                          Copyright 2022, José Martínez Hernández |
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| RENUNCIA DE GARANTÍAS                                            |
//+------------------------------------------------------------------+

//EL SOFTWARE SE ENTREGA “TAL CUAL” Y “SEGÚN DISPUESTO”, SIN GARANTÍA DE NINGÚN TIPO.
//USTED RECONOCE Y ACEPTA EXPRESAMENTE QUE TODO EL RIESGO EN CUANTO AL USO, RESULTADOS Y
//EL RENDIMIENTO DEL SOFTWARE LO ASUME EXCLUSIVAMENTE USTED.
//EN LA MEDIDA MÁXIMA PERMITIDA POR LA LEY APLICABLE, EL AUTOR RENUNCIA EXPRESAMENTE DE TODAS
//GARANTÍAS, YA SEAN EXPLÍCITAS O IMPLÍCITAS, INCLUIDAS, ENTRE OTRAS, LAS IMPLÍCITAS
//GARANTÍAS DE COMERCIABILIDAD, IDONEIDAD PARA UN FIN DETERMINADO, TÍTULO Y
//NO INFRACCIÓN O CUALQUIER GARANTÍA DERIVADA DE CUALQUIER PROPUESTA,
//ESPECIFICACION O MUESTRA RESPECTO DEL SOFTWARE, Y GARANTIAS QUE PUEDEN DARSE
//DE LA NEGOCIACIÓN, EJECUCIÓN, USO O PRÁCTICA COMERCIAL.
//SIN LIMITACIÓN DE LO ANTERIOR, EL AUTOR NO OFRECE NINGUNA GARANTÍA O COMPROMISO,
//Y NO HACE NINGUNA PROMESA DE QUE EL SOFTWARE CUMPLIRÁ CON SUS REQUISITOS,
//LOGRARÁ CUALQUIER RESULTADO PREVISTO, SERÁ COMPATIBLE O FUNCIONARÁ CON CUALQUIER OTRO SOFTWARE, SISTEMAS
//O SERVICIOS, OPERARÁ SIN INTERRUPCIONES, CUMPLIRÁ CUALQUIER ESTÁNDAR DE RENDIMIENTO O CONFIABILIDAD
//O ESTARÁ LIBRE DE ERRORES O QUE CUALQUIER ERROR O DEFECTO PODRÁ SER CORREGIDO.
//NINGUNA INFORMACIÓN ORAL O ESCRITA O CONSEJOS O RECOMENDACIONES PROPORCIONADAS POR EL 
//AUTOR DEBERÁN CREAR UNA GARANTÍA O AFECTAR DE CUALQUIER FORMA AL ALCANCE Y FUNCIONAMIENTO DE ESTA RENUNCIA.
//ESTA RENUNCIA DE GARANTÍA CONSTITUYE UNA PARTE ESENCIAL DE ESTA LICENCIA.

//+------------------------------------------------------------------+
//| Información del Asesor                                           |
//+------------------------------------------------------------------+

#property copyright "Copyright 2022-2024, José Martínez Hernández"
#property description "Asesor Experto que aplica el sistema de media móvil simple y es provisto como parte del curso en trading algorítmico" 
#property link      ""
#property version   "1.40"

//+------------------------------------------------------------------+
//| Notas del Asesor                                                 |
//+------------------------------------------------------------------+
// Asesor experto que opera una estrategia de media móvil
// Está diseñado para operar en la dirección de la tendencia, colocando posiciones de compra cuando la última barra cierra por encima de la media móvil y posiciones de venta en corto cuando la última barra cierra por debajo de la media móvil
// Incorpora dos stop loss alternativos diferentes que consisten en puntos fijos por debajo del precio de apertura o media móvil, para operaciones largas, o por encima del precio de apertura o media móvil, para operaciones cortas
// Incorpora configuraciones para colocar take profit, así como break-even y trailing stop loss

//Cambios de Versión
//v1.10  Añadida Política de llenado
//v1.20  Corregido un error en las funciones TSL y BE que causaba la modificación del take profit a 0 cuando se modificaba el stop loss 
//v1.30  Cambiadas las variables de gestión de posiciones del tipo ushort al tipo int (necesario para colocar SL o TP en mercados con más market cap como BTC)
//v1.40   
//       --TSL & BE
//       Corregido el error de invalid stops de TSL y BE. La causa era que la condición stopLossNuevo > stopLossActual a veces era cierta cuando los valores eran iguales
//       Eso puede ocurrir al comparar dos números reales, lo que se desaconseja. Así que en su lugar, ahora calculamos la diferencia y comparamos con 0
//       --TP & SL
//       Cambiamos TP y SL para usar el precio Ask para las posiciones de compra, y el precio Bid para las de venta.
//       Las posiciones de compra se cierran cuando el Bid cruza el precio especificado para el SL/TP, y las de venta cuando el precio es cruzado por el Ask.
//       Sin embargo, para establecer los precios de salida para las compras, necesitamos utilizar el precio Ask, de lo contrario estaríamos restando el spread a la distancia SL/TP, y lo contrario es cierto para los cortos.
//       Lo anterior solo afecta a los SL/TP de puntos fijos, SL basado en MA se mantiene sin cambios.
//       --Política de Llenado
//       Ahora se calcula en OnInit y se almacena en una variable global para ser utilizada bajo demanda por el EA

//+------------------------------------------------------------------+
//| AE Enumeraciones                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Variables Input y Globales                                       |
//+------------------------------------------------------------------+

sinput group                              "### AE AJUSTES GENERALES ###"
input ulong                               MagicNumber                      = 101;

sinput group                              "### AJUSTES MEDIA MÓVIL ###"
input int                                 PeriodoMA                        = 30;
input ENUM_MA_METHOD                      MetodoMA                         = MODE_SMA;
input int                                 ShiftMA                          = 0;
input ENUM_APPLIED_PRICE                  PrecioMA                         = PRICE_CLOSE;

sinput group                              "### GESTIÓN MONETARIA ###"
input double                              VolumenFijo                      = 0.1;

sinput group                              "### GESTIÓN DE POSICIONES ###"
input int                                 SLPuntosFijos                    = 0;
input int                                 SLPuntosFijosMA                  = 0;
input int                                 TPPuntosFijos                    = 0;
input int                                 TSLPuntosFijos                   = 0;
input int                                 BEPuntosFijos                    = 0;

datetime                                  glTiempoBarraApertura;
ENUM_ORDER_TYPE_FILLING                   glPoliticaLlenado;
int                                       ManejadorMA;

//+------------------------------------------------------------------+
//| Procesadores de Eventos                                          |
//+------------------------------------------------------------------+


int OnInit()
{
   //-- Inicialización de variables
   glTiempoBarraApertura = D'1971.01.01 00:00';

   if(PoliticaLLenadoPermitida(SYMBOL_FILLING_FOK))         glPoliticaLlenado = ORDER_FILLING_FOK;
   else if(PoliticaLLenadoPermitida(SYMBOL_FILLING_IOC))    glPoliticaLlenado = ORDER_FILLING_IOC;
   else                                                     glPoliticaLlenado = ORDER_FILLING_RETURN;
   
   //-- Manejadores de indicadores
   ManejadorMA = MA_Init(PeriodoMA,ShiftMA,MetodoMA,PrecioMA);
   
   if(ManejadorMA == -1) return(INIT_FAILED);
   
   return(INIT_SUCCEEDED);
}
  
void OnDeinit(const int reason)
{
   Print("Asesor eliminado");
}
  
void OnTick()
{  
   //------------------------//
   // CONTROL DE NUEVA BARRA //
   //------------------------//
   
   bool nuevaBarra = false;
   
   //Comprobación de nueva barra
   if(glTiempoBarraApertura != iTime(_Symbol,PERIOD_CURRENT,0))
   {
      nuevaBarra = true;
      glTiempoBarraApertura = iTime(_Symbol,PERIOD_CURRENT,0);
   }
   
   if(nuevaBarra == true)
   {           
      //------------------------//
      // PRECIO E INDICADORES   //
      //------------------------//
      
      //Precio
      double cierre1 = Close(1);
      double cierre2 = Close(2);
      
      //Normalización a tick size (tamaño del tick)
      double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);     
      cierre1 = round(cierre1/tickSize) * tickSize; 
      cierre2 = round(cierre2/tickSize) * tickSize;
      
      //Media Móvil (MA)
      double ma1 = ma(ManejadorMA,1);
      double ma2 = ma(ManejadorMA,2);        
      
      //------------------------//
      // CIERRE DE POSICIONES   //
      //------------------------//
      
      //Señal de cierre && Cierre de posiciones
      string exitSignal = MA_ExitSignal(cierre1,cierre2,ma1,ma2);
      
      if(exitSignal == "CIERRE_LARGO" || exitSignal == "CIERRE_CORTO"){
         CierrePosiciones(MagicNumber,exitSignal);}
         
      Sleep(1000);   
      
      //------------------------//
      // COLOCACIÓN DE ÓRDENES  //
      //------------------------//   
   
      //Señal de entrada && Colocación de posiciones      
      string entrySignal = MA_EntrySignal(cierre1,cierre2,ma1,ma2);
      Comment("A.E. #", MagicNumber, " | ", exitSignal, " | ",entrySignal, " SEÑALES DETECTADAS");
      
      if((entrySignal == "LARGO" || entrySignal == "CORTO") && RevisionPosicionesColocadas(MagicNumber) == false)
      {
         ulong ticket = AperturaTrades(entrySignal,MagicNumber,VolumenFijo);
         
         //Modificación de SL & TP
         if(ticket > 0)
         {
            double stopLoss = CalcularStopLoss(entrySignal,SLPuntosFijos,SLPuntosFijosMA,ma1);
            double takeProfit = CalcularTakeProfit(entrySignal,TPPuntosFijos); 
            ModificacionPosiciones(ticket,MagicNumber,stopLoss,takeProfit);        
         }
      }
           
      //------------------------//
      // GESTIÓN DE POSICIONES  //
      //------------------------//
      
      if(TSLPuntosFijos > 0) TrailingStopLoss(MagicNumber,TSLPuntosFijos);
      if(BEPuntosFijos > 0) BreakEven(MagicNumber,BEPuntosFijos);
   }
}


//+------------------------------------------------------------------+
//| AE Funciones                                                     |
//+------------------------------------------------------------------+

//+----------+// Funciones del Precio //+----------+//

double Close(int pShift)
{
   MqlRates barra[];                            //Crea un objeto array del tipo estructura MqlRates
   ArraySetAsSeries(barra,true);                //Configura nuestro array como un array en serie (la vela actual se copiará en índice 0, la vela 1 en índice 1 y sucesivamente)
   CopyRates(_Symbol,PERIOD_CURRENT,0,3,barra); //Copia datos del precio de barras 0, 1 y 2 a nuestro array barra
   
   return barra[pShift].close;                  //Retorna precio de cierre del objeto barra
}

double Open(int pShift)
{
   MqlRates barra[];                            //Crea un objeto array del tipo estructura MqlRates
   ArraySetAsSeries(barra,true);                //Configura nuestro array como un array en serie (la vela actual se copiará en índice 0, la vela 1 en índice 1 y sucesivamente)
   CopyRates(_Symbol,PERIOD_CURRENT,0,3,barra); //Copia datos del precio de barras 0, 1 y 2 a nuestro array barra
   
   return barra[pShift].open;                   //Retorna precio de apertura del objeto barra
}

//+----------+// Funciones de la Media Móvil //+----------+//

int MA_Init(int pPeriodoMA,int pShiftMA,ENUM_MA_METHOD pMetodoMA,ENUM_APPLIED_PRICE pPrecioMA)
{
   //En caso de error al inicializar el MA, GetLastError() nos dará el código del error y lo almacenará en _LastError
   //ResetLastError cambiará el valor de la variable _LastError a 0
   ResetLastError();
   
   //El manejador es un identificador único para el indicador. Se utiliza para todas las acciones relacionadas con este, como obtener datos o eliminarlo
   int Manejador = iMA(_Symbol,PERIOD_CURRENT,pPeriodoMA,pShiftMA,pMetodoMA,pPrecioMA);
   
   if(Manejador == INVALID_HANDLE)
   {
      return -1;
      Print("Ha habido un error creando el manejador del indicador MA: ", GetLastError());
   }
   
   Print("El manejador del indicador MA se ha creado con éxito");
   
   return Manejador;
}

double ma(int pManejadorMA, int pShift)
{
   ResetLastError();
   
   //Creamos un array que llenaremos con los precios del indicador
   double ma[];
   ArraySetAsSeries(ma,true);
   
   //Llenamos el array con los 3 valores más recientes del MA
   bool resultado = CopyBuffer(pManejadorMA,0,0,3,ma);
   if(resultado == false){
      Print("ERROR AL COPIAR DATOS: ", GetLastError());}
      
   //Preguntamos por el valor del indicador almacenado en pShift
   double valorMA = ma[pShift];
   
   //Normalizamos valorMA a los dígitos de nuestro símbolo y lo retornamos
   valorMA = NormalizeDouble(valorMA,_Digits);
   
   return valorMA;   
}

string MA_EntrySignal(double pPrecio1, double pPrecio2, double pMA1, double pMA2)
{
   string str = "";
   string valores;
   
   if(pPrecio1 > pMA1 && pPrecio2 <= pMA2) {str = "LARGO";}
   else if(pPrecio1 < pMA1 && pPrecio2 >= pMA2) {str = "CORTO";}
   else {str = "NO_OPERAR";}
   
   StringConcatenate(valores,"MA 1: ", DoubleToString(pMA1,_Digits), " | ", "MA 2: ", DoubleToString(pMA2,_Digits), " | ",
                     "Cierre 1: ", DoubleToString(pPrecio1,_Digits), " | ", "Cierre 2: ", DoubleToString(pPrecio2,_Digits));
   
   Print("Valores del precio e indicadores: ", valores);
   
   return str;
}

string MA_ExitSignal(double pPrecio1, double pPrecio2, double pMA1, double pMA2)
{
   string str = "";
   string valores;
   
   if(pPrecio1 > pMA1 && pPrecio2 <= pMA2) {str = "CIERRE_CORTO";}
   else if(pPrecio1 < pMA1 && pPrecio2 >= pMA2) {str = "CIERRE_LARGO";}
   else {str = "NO_CIERRE";}
   
   StringConcatenate(valores,"MA 1: ", DoubleToString(pMA1,_Digits), " | ", "MA 2: ", DoubleToString(pMA2,_Digits), " | ",
                     "Cierre 1: ", DoubleToString(pPrecio1,_Digits), " | ", "Cierre 2: ", DoubleToString(pPrecio2,_Digits));
   
   Print("Valores del precio e indicadores: ", valores);
   
   return str;
}

//+----------+// Funciones de las Bandas de Bollinger //+----------+//

int BB_Init(int pPeriodoBB,int pShiftBB,double pDesviacionBB,ENUM_APPLIED_PRICE pPrecioBB)
{
   //En caso de error al inicializar las BB, GetLastError() nos dará el código del error y lo almacenará en _LastError
   //ResetLastError cambiará el valor de la variable _LastError a 0
   ResetLastError();
   
   //El manejador es un identificador único para el indicador. Se utiliza para todas las acciones relacionadas con este, como obtener datos o eliminarlo
   int Manejador = iBands(_Symbol,PERIOD_CURRENT,pPeriodoBB,pShiftBB,pDesviacionBB,pPrecioBB);
   
   if(Manejador == INVALID_HANDLE)
   {
      return -1;
      Print("Ha habido un error creando el manejador del indicador BB: ", GetLastError());
   }
   
   Print("El manejador del indicador BB se ha creado con éxito");
   
   return Manejador;
}

double BB(int pManejadorBB, int pBuffer, int pShift)
{
   ResetLastError();
   
   //Creamos un array que llenaremos con los precios del indicador
   double BB[];
   ArraySetAsSeries(BB,true);
   
   //Llenamos el array con los 3 valores más recientes del BB
   bool resultado = CopyBuffer(pManejadorBB,pBuffer,0,3,BB);
   if(resultado == false){
      Print("ERROR AL COPIAR DATOS: ", GetLastError());}
      
   //Preguntamos por el valor del indicador almacenado en pShift
   double valorBB = BB[pShift];
   
   //Normalizamos valorBB a los dígitos de nuestro símbolo y lo retornamos
   valorBB = NormalizeDouble(valorBB,_Digits);
   
   return valorBB;   
}

//+----------+// Funciones para la Colocación de Órdenes//+----------+//

ulong AperturaTrades(string pEntrySignal, ulong pMagicNumber, double pVolumenFijo)
{
   //Compramos al Ask pero cerramos al Bid
   //Vendemos al Bid pero cerramos al Ask
   
   double precioAsk  = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double precioBid  = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize   = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   
   //Precio debe ser normalizado a dígitos o tamaño del tick (ticksize)
   precioAsk = round(precioAsk/tickSize) * tickSize;
   precioBid = round(precioBid/tickSize) * tickSize;
   
   string comentario = pEntrySignal + " | " + _Symbol + " | " + string(pMagicNumber);
   
   //Declaración e inicialización de los objetos solicitud y resultado
   MqlTradeRequest solicitud  = {};
   MqlTradeResult resultado   = {}; 
   
   if(pEntrySignal == "LARGO")
   {
      //Parámetros de la solicitud
      solicitud.action        = TRADE_ACTION_DEAL;
      solicitud.symbol        = _Symbol;
      solicitud.volume        = pVolumenFijo;
      solicitud.type          = ORDER_TYPE_BUY;
      solicitud.price         = precioAsk;
      solicitud.deviation     = 30;
      solicitud.magic         = pMagicNumber;
      solicitud.comment       = comentario;
      solicitud.type_filling  = glPoliticaLlenado;
      
      //Envío de la solicitud
      if(!OrderSend(solicitud,resultado))
         Print("Error en el envío de la orden: ", GetLastError());      //Si la solicitud no se envía, imprimimos código de error
      
      //Información de la operación
      Print("Abierta ", solicitud.symbol, " ",pEntrySignal," orden #",resultado.order,": ",resultado.retcode,", Volumen: ",resultado.volume,", Precio: ",DoubleToString(precioAsk,_Digits));
         
   }
   else if(pEntrySignal == "CORTO")
   {
      //Parámetros de la solicitud
      solicitud.action        = TRADE_ACTION_DEAL;
      solicitud.symbol        = _Symbol;
      solicitud.volume        = pVolumenFijo;
      solicitud.type          = ORDER_TYPE_SELL;
      solicitud.price         = precioBid;
      solicitud.deviation     = 30;
      solicitud.magic         = pMagicNumber;
      solicitud.comment       = comentario;
      solicitud.type_filling  = glPoliticaLlenado;
      
      //Envío de la solicitud
      if(!OrderSend(solicitud,resultado))
         Print("Error en el envío de la orden: ", GetLastError());      //Si la solicitud no se envía, imprimimos código de error
      
      //Información de la operación
      Print("Abierta ", solicitud.symbol, " ",pEntrySignal," orden #",resultado.order,": ",resultado.retcode,", Volumen: ",resultado.volume,", Precio: ",DoubleToString(precioBid,_Digits));   
   }
   
   if(resultado.retcode == TRADE_RETCODE_DONE || resultado.retcode == TRADE_RETCODE_DONE_PARTIAL || resultado.retcode == TRADE_RETCODE_PLACED || resultado.retcode == TRADE_RETCODE_NO_CHANGES)
   {
      return resultado.order;
   }
   else return 0;      
}

void ModificacionPosiciones(ulong pTicket, ulong pMagicNumber, double pSLPrecio, double pTPPrecio)
{
   double tickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   
   MqlTradeRequest solicitud  = {};
   MqlTradeResult resultado   = {};
   
   solicitud.action = TRADE_ACTION_SLTP;
   solicitud.position = pTicket;
   solicitud.symbol = _Symbol;
   solicitud.sl = round(pSLPrecio/tickSize) * tickSize;
   solicitud.tp = round(pTPPrecio/tickSize) * tickSize;
   solicitud.comment = "MOD. " + " | " + _Symbol + " | " + string(pMagicNumber) + ", SL: " + DoubleToString(solicitud.sl,_Digits) + ", TP: " + DoubleToString(solicitud.tp,_Digits);
   
   if(solicitud.sl > 0 || solicitud.tp > 0)
   {
      Sleep(1000);
      bool sent = OrderSend(solicitud,resultado);
      Print(resultado.comment);
      
      if(!sent)
      {
         Print("Error de modificación OrderSend: ", GetLastError());
         Sleep(3000);
         
         sent = OrderSend(solicitud,resultado);
         Print(resultado.comment);
         if(!sent) Print("2o intento error de modificación OrderSend: ", GetLastError());
      }
   } 
}

bool RevisionPosicionesColocadas(ulong pMagicNumber)
{
   bool posicionColocada = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong posicionTicket = PositionGetTicket(i);
      PositionSelectByTicket(posicionTicket);
      
      ulong posicionMagico = PositionGetInteger(POSITION_MAGIC);
      
      if(posicionMagico == pMagicNumber)
      {
         posicionColocada = true;
         break;
      }
   }
   
   return posicionColocada;
}

void CierrePosiciones(ulong pMagicNumber, string pExitSignal)
{
   //Declaración e inicialización de los objetos solicitud y resultado
   MqlTradeRequest solicitud  = {};
   MqlTradeResult resultado   = {};
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      //Reset de los valores de los objetos solicitud y resultado
      ZeroMemory(solicitud);
      ZeroMemory(resultado);
      
      ulong posicionTicket = PositionGetTicket(i);
      PositionSelectByTicket(posicionTicket);
      
      ulong posicionMagico = PositionGetInteger(POSITION_MAGIC);
      ulong posicionTipo = PositionGetInteger(POSITION_TYPE);
      
      if(posicionMagico == pMagicNumber && pExitSignal == "CIERRE_LARGO" && posicionTipo == POSITION_TYPE_BUY)
      {
         solicitud.action        = TRADE_ACTION_DEAL;
         solicitud.type          = ORDER_TYPE_SELL;
         solicitud.symbol        = _Symbol;
         solicitud.position      = posicionTicket;
         solicitud.volume        = PositionGetDouble(POSITION_VOLUME);
         solicitud.price         = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         solicitud.deviation     = 30;
         solicitud.type_filling  = glPoliticaLlenado;
         
         bool sent = OrderSend(solicitud,resultado);
         if(sent == true){Print("Posición #",posicionTicket, " cerrada");}
      } 
      else if(posicionMagico == pMagicNumber && pExitSignal == "CIERRE_CORTO" && posicionTipo == POSITION_TYPE_SELL)
      {
         solicitud.action        = TRADE_ACTION_DEAL;
         solicitud.type          = ORDER_TYPE_BUY;
         solicitud.symbol        = _Symbol;
         solicitud.position      = posicionTicket;
         solicitud.volume        = PositionGetDouble(POSITION_VOLUME);
         solicitud.price         = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         solicitud.deviation     = 30;
         solicitud.type_filling  = glPoliticaLlenado;
         
         bool sent = OrderSend(solicitud,resultado);
         if(sent == true){Print("Posición #",posicionTicket, " cerrada");}      
      }      
   }      
}

//+----------+// Funciones para la Gestión de posiciones //+----------+//

double CalcularStopLoss(string pEntrySignal, int pSLPuntosFijos, int pSLPuntosFijosMA, double pMA)
{
   double stopLoss   = 0.0;
   double precioAsk  = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double precioBid  = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize   = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   
   if(pEntrySignal == "LARGO")
   {
      if(pSLPuntosFijos > 0){
         stopLoss = precioAsk - (pSLPuntosFijos * _Point);}
      else if(pSLPuntosFijosMA > 0){
         stopLoss = pMA - (pSLPuntosFijosMA * _Point);}
      
      if(stopLoss > 0) stopLoss = AjusteNivelStopDebajo(precioAsk,stopLoss);   
   }
   if(pEntrySignal == "CORTO")
   {
      if(pSLPuntosFijos > 0){
         stopLoss = precioBid + (pSLPuntosFijos * _Point);}
      else if(pSLPuntosFijosMA > 0){
         stopLoss = pMA + (pSLPuntosFijosMA * _Point);}
      
      if(stopLoss > 0) stopLoss = AjusteNivelStopArriba(precioBid,stopLoss);   
   }
   
   stopLoss = round(stopLoss/tickSize) * tickSize;
   return stopLoss;   
}

double CalcularTakeProfit(string pEntrySignal, int pTPPuntosFijos)
{
   double takeProfit = 0.0;
   double precioAsk  = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double precioBid  = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tickSize   = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   
   if(pEntrySignal == "LARGO")
   {
      if(pTPPuntosFijos > 0){
         takeProfit = precioAsk + (pTPPuntosFijos * _Point);}
      
      if(takeProfit > 0) takeProfit = AjusteNivelStopArriba(precioAsk,takeProfit);   
   
   }
   if(pEntrySignal == "CORTO")
   {
      if(pTPPuntosFijos > 0){
         takeProfit = precioBid - (pTPPuntosFijos * _Point);}
      
      if(takeProfit > 0) takeProfit = AjusteNivelStopDebajo(precioBid,takeProfit);      
   }
   
   takeProfit = round(takeProfit/tickSize) * tickSize;
   return takeProfit;   
}

void TrailingStopLoss(ulong pNumeroMagico, int pTSLPuntosFijos)
{
   //Declaración e inicialización de los objetos solicitud y resultado
   MqlTradeRequest solicitud  = {};
   MqlTradeResult resultado   = {};
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      //Reset de los valores de los objetos solicitud y resultado
      ZeroMemory(solicitud);
      ZeroMemory(resultado);
      
      ulong posicionTicket = PositionGetTicket(i);
      PositionSelectByTicket(posicionTicket);
      
      ulong posicionMagico    = PositionGetInteger(POSITION_MAGIC);
      ulong posicionTipo      = PositionGetInteger(POSITION_TYPE);
      double stopLossActual   = PositionGetDouble(POSITION_SL);
      double tickSize         = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      
      double precioBid        = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double precioAsk        = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      
      double stopLossNuevo;
      
      if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_BUY)
      {
         stopLossNuevo = precioAsk - (pTSLPuntosFijos * _Point);
         stopLossNuevo = AjusteNivelStopDebajo(precioAsk,stopLossNuevo);
         stopLossNuevo = round(stopLossNuevo/tickSize) * tickSize;
         
         if(NormalizeDouble(stopLossNuevo-stopLossActual,_Digits) > 0 || stopLossActual==0)
         {
            solicitud.action = TRADE_ACTION_SLTP;
            solicitud.position = posicionTicket;
            solicitud.comment = "TSL. " + _Symbol + " | " + string(pNumeroMagico);
            solicitud.sl = stopLossNuevo;
            solicitud.tp = PositionGetDouble(POSITION_TP);
            
            bool sent = OrderSend(solicitud,resultado);
            if(!sent) Print("OrderSend TSL error: ", GetLastError());
         }
      }
      else if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_SELL)
      {
         stopLossNuevo = precioBid + (pTSLPuntosFijos * _Point);
         stopLossNuevo = AjusteNivelStopArriba(precioBid,stopLossNuevo);         
         stopLossNuevo = round(stopLossNuevo/tickSize) * tickSize;
         
         if(NormalizeDouble(stopLossNuevo-stopLossActual,_Digits) < 0 || stopLossActual==0)         
         {
            solicitud.action = TRADE_ACTION_SLTP;
            solicitud.position = posicionTicket;
            solicitud.comment = "TSL. " + _Symbol + " | " + string(pNumeroMagico);
            solicitud.sl = stopLossNuevo;
            solicitud.tp = PositionGetDouble(POSITION_TP);
            
            bool sent = OrderSend(solicitud,resultado);
            if(!sent) Print("OrderSend TSL error: ", GetLastError());
         }      
      }      
   }      
}

void BreakEven(ulong pNumeroMagico, int pBEPuntosFijos)
{
   //Declaración e inicialización de los objetos solicitud y resultado
   MqlTradeRequest solicitud  = {};
   MqlTradeResult resultado   = {};
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      //Reset de los valores de los objetos solicitud y resultado
      ZeroMemory(solicitud);
      ZeroMemory(resultado);
      
      ulong posicionTicket = PositionGetTicket(i);
      PositionSelectByTicket(posicionTicket);
      
      ulong posicionMagico    = PositionGetInteger(POSITION_MAGIC);
      ulong posicionTipo      = PositionGetInteger(POSITION_TYPE);
      double stopLossActual   = PositionGetDouble(POSITION_SL);
      double tickSize         = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double precioApertura   = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLossNuevo    = round(precioApertura/tickSize) * tickSize;
      
      if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_BUY)
      {
         double precioBid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double BEDistancia = precioApertura + (pBEPuntosFijos * _Point);

         if((NormalizeDouble(stopLossNuevo-stopLossActual,_Digits) > 0 || stopLossActual==0) && precioBid > BEDistancia)         
         {
            solicitud.action = TRADE_ACTION_SLTP;
            solicitud.position = posicionTicket;
            solicitud.comment = "BE. " + _Symbol + " | " + string(pNumeroMagico);
            solicitud.sl = stopLossNuevo;
            solicitud.tp = PositionGetDouble(POSITION_TP);
            
            bool sent = OrderSend(solicitud,resultado);
            if(!sent) Print("OrderSend BE error: ", GetLastError());
         }
      }
      else if(posicionMagico == pNumeroMagico && posicionTipo == POSITION_TYPE_SELL)
      {
         double precioAsk = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double BEDistancia = precioApertura - (pBEPuntosFijos * _Point);

         if((NormalizeDouble(stopLossNuevo-stopLossActual,_Digits) < 0 || stopLossActual==0) && precioAsk < BEDistancia)                          
         {
            solicitud.action = TRADE_ACTION_SLTP;
            solicitud.position = posicionTicket;
            solicitud.comment = "BE. " + _Symbol + " | " + string(pNumeroMagico);
            solicitud.sl = stopLossNuevo;
            solicitud.tp = PositionGetDouble(POSITION_TP);
            
            bool sent = OrderSend(solicitud,resultado);
            if(!sent) Print("OrderSend BE error: ", GetLastError());
         }      
      }      
   }      
}

//Ajuste de niveles de stops
double AjusteNivelStopArriba(double pPrecioActual,double pPrecioParaAjustar,int pPuntosAdicionales = 10)
{
   double precioAjustado = pPrecioParaAjustar;
   
   long nivelesStop = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   
   if(nivelesStop > 0)
   {
      double nivelesStopPrecio = nivelesStop * _Point;
      nivelesStopPrecio = pPrecioActual + nivelesStopPrecio;
      
      double puntosAdicionales = pPuntosAdicionales * _Point;
      
      if(precioAjustado <= nivelesStopPrecio + puntosAdicionales)
      {
         precioAjustado = nivelesStopPrecio + puntosAdicionales;
         Print("Precio ajustado por encima del nivel de stops a " + string(precioAjustado));
      }
   }
   
   return precioAjustado;
}

//Ajuste de niveles de stops
double AjusteNivelStopDebajo(double pPrecioActual,double pPrecioParaAjustar,int pPuntosAdicionales = 10)
{
   double precioAjustado = pPrecioParaAjustar;
   
   long nivelesStop = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   
   if(nivelesStop > 0)
   {
      double nivelesStopPrecio = nivelesStop * _Point;
      nivelesStopPrecio = pPrecioActual - nivelesStopPrecio;
      
      double puntosAdicionales = pPuntosAdicionales * _Point;
      
      if(precioAjustado >= nivelesStopPrecio - puntosAdicionales)
      {
         precioAjustado = nivelesStopPrecio - puntosAdicionales;
         Print("Precio ajustado por debajo del nivel de stops a " + string(precioAjustado));
      }
   }
   
   return precioAjustado;
}

//Política de llenado
bool PoliticaLLenadoPermitida(int pTipoLlenado) 
{
    //--- obtenemos el valor de la propiedad que describe el modo de rellenado
    int simboloTipoLLenado = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    //--- retornamos true, si el modo fill_type está permitido
    return ((simboloTipoLLenado & pTipoLlenado) == pTipoLlenado);
}
